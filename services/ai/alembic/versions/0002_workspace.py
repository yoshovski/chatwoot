"""Encrypted shared Dify connection, scoped to the Chatwoot installation."""

from alembic import op

revision = "0002_workspace"
down_revision = "0001_knowledge"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
CREATE TABLE workspace_settings (
    installation_id VARCHAR(100) PRIMARY KEY,
    enabled BOOLEAN NOT NULL,
    encrypted_connection TEXT
)
""")


def downgrade():
    op.drop_table("workspace_settings")
