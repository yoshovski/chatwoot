import argparse

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from cwai import schema as s
from cwai.config import settings
from cwai.db import engine


def main():
    parser = argparse.ArgumentParser(
        description="Provision a server-owned Chatwoot account binding"
    )
    parser.add_argument("account_id", type=int)
    parser.add_argument("--credential-ref", required=True)
    parser.add_argument("--enable", action="store_true")
    args = parser.parse_args()
    config = settings()
    if args.account_id <= 0:
        parser.error("account_id must be positive")
    if args.credential_ref not in config.dify_connections:
        parser.error("credential-ref must name a server-configured Dify connection")
    with engine().begin() as conn:
        existing = (
            conn.execute(
                select(s.accounts)
                .where(
                    s.accounts.c.installation_id == config.installation_id,
                    s.accounts.c.account_id == args.account_id,
                )
                .with_for_update()
            )
            .mappings()
            .one_or_none()
        )
        if existing and existing["credential_ref"] != args.credential_ref:
            parser.error("Changing a credential binding requires an explicit index migration")
        conn.execute(
            insert(s.accounts)
            .values(
                installation_id=config.installation_id,
                account_id=args.account_id,
                credential_ref=args.credential_ref,
                enabled=args.enable,
            )
            .on_conflict_do_update(
                index_elements=["installation_id", "account_id"],
                set_={
                    "credential_ref": args.credential_ref,
                    "enabled": args.enable,
                },
            )
        )
        tenant_id = conn.scalar(
            select(s.accounts.c.id).where(
                s.accounts.c.installation_id == config.installation_id,
                s.accounts.c.account_id == args.account_id,
            )
        )
    print(f"Provisioned account {args.account_id}: {tenant_id}")
