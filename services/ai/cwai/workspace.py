import base64
import hashlib
import json

from cryptography.fernet import Fernet
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, ConfigDict, model_validator
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from cwai.auth import configuration_scope
from cwai.config import DifyConnection, settings
from cwai.db import engine
from cwai.schema import accounts, workspace_settings

router = APIRouter(prefix="/v1/knowledge")


def cipher():
    # Domain separation keeps stored configuration encryption distinct from JWT signing.
    material = b"cwai-workspace-v1\0" + settings().signing_key.get_secret_value().encode()
    return Fernet(base64.urlsafe_b64encode(hashlib.sha256(material).digest()))


def shared_workspace(conn):
    return (
        conn.execute(
            select(workspace_settings).where(
                workspace_settings.c.installation_id == settings().installation_id,
                workspace_settings.c.enabled.is_(True),
            )
        )
        .mappings()
        .one_or_none()
    )


def connection(credential_ref):
    config = settings()
    if credential_ref == config.default_connection_ref:
        with engine().connect() as conn:
            row = shared_workspace(conn)
        if row:
            return DifyConnection.model_validate_json(
                cipher().decrypt(row["encrypted_connection"].encode())
            )
    return config.dify_connections[credential_ref]


class WorkspaceUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True, strict=True)
    enabled: bool
    connection: DifyConnection | None = None

    @model_validator(mode="after")
    def require_connection(self):
        if self.enabled and self.connection is None:
            raise ValueError("Enabled workspace requires a connection")
        return self


@router.put("/workspace", status_code=204, dependencies=[Depends(configuration_scope)])
def configure_workspace(payload: WorkspaceUpdate):
    config = settings()
    if config.default_connection_ref not in config.dify_connections:
        raise HTTPException(422, "Default Dify connection must be configured on the server")
    encrypted = None
    if payload.enabled:
        values = payload.connection.model_dump(mode="json")
        values["api_key"] = payload.connection.api_key.get_secret_value()
        encrypted = cipher().encrypt(json.dumps(values).encode()).decode()
    with engine().begin() as conn:
        if payload.enabled and conn.scalar(
            select(accounts.c.id)
            .where(
                accounts.c.installation_id == config.installation_id,
                accounts.c.enabled.is_(True),
                accounts.c.credential_ref != config.default_connection_ref,
            )
            .limit(1)
        ):
            raise HTTPException(409, "Existing accounts require a workspace migration")
        conn.execute(
            insert(workspace_settings)
            .values(
                installation_id=config.installation_id,
                enabled=payload.enabled,
                encrypted_connection=encrypted,
            )
            .on_conflict_do_update(
                index_elements=["installation_id"],
                set_={"enabled": payload.enabled, "encrypted_connection": encrypted},
            )
        )
    return Response(status_code=204)
