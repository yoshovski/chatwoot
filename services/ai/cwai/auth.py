from dataclasses import dataclass

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select

from cwai.config import settings
from cwai.db import engine
from cwai.schema import accounts

bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Scope:
    tenant_id: str
    actor: str
    action: str


def scope(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)) -> Scope:
    config = settings()
    if not config.enabled:
        raise HTTPException(404, "Knowledge is not enabled")
    if not credentials:
        raise HTTPException(401, "Service credential required")
    try:
        claims = jwt.decode(
            credentials.credentials,
            config.signing_key.get_secret_value(),
            algorithms=["HS256"],
            audience=config.audience,
            issuer=config.installation_id,
            options={"require": ["exp", "iat", "nbf", "iss", "aud", "sub", "account_id", "action"]},
        )
        if (
            any(type(claims[k]) is not int for k in ("exp", "iat", "nbf"))
            or type(claims["sub"]) is not str
            or type(claims["account_id"]) is not int
            or claims["account_id"] <= 0
            or not claims["sub"]
            or len(claims["sub"]) > 100
            or type(claims["action"]) is not str
            or claims["action"] not in {"knowledge:read", "knowledge:write"}
            or claims["exp"] - claims["iat"] > 60
        ):
            raise jwt.InvalidTokenError()
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid service credential") from None
    with engine().connect() as conn:
        tenant = (
            conn.execute(
                select(accounts).where(
                    accounts.c.installation_id == claims["iss"],
                    accounts.c.account_id == claims["account_id"],
                    accounts.c.enabled.is_(True),
                )
            )
            .mappings()
            .one_or_none()
        )
    if tenant is None:
        raise HTTPException(403, "Account is not provisioned")
    return Scope(tenant["id"], claims["sub"], claims["action"])


def read_scope(value: Scope = Depends(scope)) -> Scope:
    if value.action != "knowledge:read":
        raise HTTPException(403, "Read permission required")
    return value


def write_scope(value: Scope = Depends(scope)) -> Scope:
    if value.action != "knowledge:write":
        raise HTTPException(403, "Write permission required")
    return value
