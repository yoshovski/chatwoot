"""Canonical account-owned knowledge. Frozen DDL; independent of future schema edits."""

from alembic import op

revision = "0001_knowledge"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
CREATE TABLE account_bindings (
    id UUID NOT NULL,
    installation_id VARCHAR(100) NOT NULL,
    account_id BIGINT NOT NULL,
    credential_ref VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (installation_id, account_id),
    CHECK (account_id > 0)
)

""")
    op.execute("""
CREATE TABLE agents (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    chatwoot_agent_bot_id BIGINT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, chatwoot_agent_bot_id),
    CHECK (chatwoot_agent_bot_id > 0),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""
CREATE TABLE knowledge_bases (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    name VARCHAR(200) NOT NULL,
    enabled BOOLEAN NOT NULL,
    generation INTEGER NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""
CREATE TABLE agent_knowledge_bases (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    agent_id UUID NOT NULL,
    base_id UUID NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(tenant_id, agent_id) REFERENCES agents (tenant_id, id),
    FOREIGN KEY(tenant_id, base_id) REFERENCES knowledge_bases (tenant_id, id),
    UNIQUE (tenant_id, agent_id, base_id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""
CREATE TABLE index_projections (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    base_id UUID NOT NULL,
    kind VARCHAR(10) NOT NULL,
    dataset_id VARCHAR(100),
    epoch INTEGER NOT NULL,
    PRIMARY KEY (id),
    CHECK (kind IN ('faq', 'document')),
    FOREIGN KEY(tenant_id, base_id) REFERENCES knowledge_bases (tenant_id, id),
    UNIQUE (tenant_id, base_id, kind),
    UNIQUE (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""
CREATE TABLE sources (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    base_id UUID NOT NULL,
    enabled BOOLEAN NOT NULL,
    version INTEGER NOT NULL,
    generation INTEGER NOT NULL,
    name VARCHAR(200) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(tenant_id, base_id) REFERENCES knowledge_bases (tenant_id, id),
    UNIQUE (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""CREATE INDEX sources_by_base ON sources (tenant_id, base_id)""")
    op.execute("""
CREATE TABLE knowledge_entries (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    base_id UUID NOT NULL,
    enabled BOOLEAN NOT NULL,
    version INTEGER NOT NULL,
    generation INTEGER NOT NULL,
    source_id UUID,
    review_state VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    CHECK (review_state IN ('draft', 'approved')),
    FOREIGN KEY(tenant_id, base_id, source_id) REFERENCES sources (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id, base_id) REFERENCES knowledge_bases (tenant_id, id),
    UNIQUE (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""CREATE INDEX entries_by_base ON knowledge_entries (tenant_id, base_id)""")
    op.execute("""
CREATE TABLE source_revisions (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    base_id UUID NOT NULL,
    parent_id UUID NOT NULL,
    version INTEGER NOT NULL,
    actor VARCHAR(100) NOT NULL,
    provenance JSON NOT NULL,
    text TEXT NOT NULL,
    source_url TEXT,
    original_key TEXT,
    original_sha256 VARCHAR(64),
    filename VARCHAR(200),
    media_type VARCHAR(100),
    PRIMARY KEY (id),
    UNIQUE (tenant_id, base_id, id),
    UNIQUE (tenant_id, parent_id, version),
    FOREIGN KEY(tenant_id, base_id, parent_id) REFERENCES sources (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""
CREATE TABLE entry_revisions (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    base_id UUID NOT NULL,
    parent_id UUID NOT NULL,
    version INTEGER NOT NULL,
    actor VARCHAR(100) NOT NULL,
    provenance JSON NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    source_revision_id UUID,
    PRIMARY KEY (id),
    FOREIGN KEY(tenant_id, base_id, source_revision_id) REFERENCES source_revisions (tenant_id, base_id, id),
    UNIQUE (tenant_id, base_id, id),
    UNIQUE (tenant_id, parent_id, version),
    FOREIGN KEY(tenant_id, base_id, parent_id) REFERENCES knowledge_entries (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""
CREATE TABLE index_jobs (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    base_id UUID NOT NULL,
    projection_id UUID NOT NULL,
    entry_id UUID,
    source_id UUID,
    generation INTEGER NOT NULL,
    epoch INTEGER NOT NULL,
    state VARCHAR(20) NOT NULL,
    attempts INTEGER NOT NULL,
    available_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    last_error VARCHAR(100),
    PRIMARY KEY (id),
    CHECK (state IN ('pending', 'done', 'failed', 'superseded')),
    CHECK ((entry_id IS NULL) <> (source_id IS NULL)),
    FOREIGN KEY(tenant_id, base_id, projection_id) REFERENCES index_projections (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id, base_id, entry_id) REFERENCES knowledge_entries (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id, base_id, source_id) REFERENCES sources (tenant_id, base_id, id),
    UNIQUE (projection_id, epoch, entry_id, generation),
    UNIQUE (projection_id, epoch, source_id, generation),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""CREATE INDEX index_jobs_due ON index_jobs (state, available_at)""")
    op.execute("""
CREATE TABLE index_bindings (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    base_id UUID NOT NULL,
    projection_id UUID NOT NULL,
    entry_revision_id UUID,
    source_revision_id UUID,
    epoch INTEGER NOT NULL,
    document_id VARCHAR(100),
    batch_id VARCHAR(100),
    index_started_at TIMESTAMP WITH TIME ZONE,
    segment_ids JSON NOT NULL,
    state VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    CHECK (state IN ('pending', 'indexing', 'ready', 'retired')),
    CHECK ((entry_revision_id IS NULL) <> (source_revision_id IS NULL)),
    FOREIGN KEY(tenant_id, base_id, projection_id) REFERENCES index_projections (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id, base_id, entry_revision_id) REFERENCES entry_revisions (tenant_id, base_id, id),
    FOREIGN KEY(tenant_id, base_id, source_revision_id) REFERENCES source_revisions (tenant_id, base_id, id),
    UNIQUE (projection_id, epoch, entry_revision_id),
    UNIQUE (projection_id, epoch, source_revision_id),
    UNIQUE (projection_id, document_id),
    FOREIGN KEY(tenant_id) REFERENCES account_bindings (id),
    UNIQUE (tenant_id, id)
)

""")
    op.execute("""CREATE FUNCTION cwai_immutable_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Canonical revisions are immutable';
END $$""")
    op.execute(
        """CREATE TRIGGER immutable_revision BEFORE UPDATE OR DELETE ON source_revisions FOR EACH ROW EXECUTE FUNCTION cwai_immutable_revision()"""
    )
    op.execute(
        """CREATE TRIGGER immutable_revision BEFORE UPDATE OR DELETE ON entry_revisions FOR EACH ROW EXECUTE FUNCTION cwai_immutable_revision()"""
    )


def downgrade():
    raise RuntimeError(
        "Restore canonical records and originals from backup before reverting this schema"
    )
