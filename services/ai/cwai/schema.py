from uuid import uuid4

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKeyConstraint,
    Index,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)

metadata = MetaData()


def identity():
    return Column("id", Uuid(as_uuid=False), primary_key=True, default=lambda: str(uuid4()))


def tenant_table(name, *columns):
    return Table(
        name,
        metadata,
        identity(),
        Column("tenant_id", Uuid(as_uuid=False), nullable=False),
        Column("created_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
        ForeignKeyConstraint(["tenant_id"], ["account_bindings.id"]),
        UniqueConstraint("tenant_id", "id"),
        *columns,
    )


accounts = Table(
    "account_bindings",
    metadata,
    identity(),
    Column("installation_id", String(100), nullable=False),
    Column("account_id", BigInteger, nullable=False),
    Column("credential_ref", String(100), nullable=False),
    Column("enabled", Boolean, nullable=False, default=False),
    UniqueConstraint("installation_id", "account_id"),
    CheckConstraint("account_id > 0"),
)
bases = tenant_table(
    "knowledge_bases",
    Column("name", String(200), nullable=False),
    Column("enabled", Boolean, nullable=False, default=True),
    Column("generation", Integer, nullable=False, default=1),
)
agents = tenant_table(
    "agents",
    Column("chatwoot_agent_bot_id", BigInteger, nullable=False),
    UniqueConstraint("tenant_id", "chatwoot_agent_bot_id"),
    CheckConstraint("chatwoot_agent_bot_id > 0"),
)
attachments = tenant_table(
    "agent_knowledge_bases",
    Column("agent_id", Uuid(as_uuid=False), nullable=False),
    Column("base_id", Uuid(as_uuid=False), nullable=False),
    ForeignKeyConstraint(["tenant_id", "agent_id"], ["agents.tenant_id", "agents.id"]),
    ForeignKeyConstraint(
        ["tenant_id", "base_id"], ["knowledge_bases.tenant_id", "knowledge_bases.id"]
    ),
    UniqueConstraint("tenant_id", "agent_id", "base_id"),
)


def content_table(name, *extra):
    return tenant_table(
        name,
        Column("base_id", Uuid(as_uuid=False), nullable=False),
        Column("enabled", Boolean, nullable=False, default=True),
        Column("version", Integer, nullable=False, default=1),
        Column("generation", Integer, nullable=False, default=1),
        ForeignKeyConstraint(
            ["tenant_id", "base_id"], ["knowledge_bases.tenant_id", "knowledge_bases.id"]
        ),
        UniqueConstraint("tenant_id", "base_id", "id"),
        *extra,
    )


sources = content_table("sources", Column("name", String(200), nullable=False))
entries = content_table(
    "knowledge_entries",
    Column("source_id", Uuid(as_uuid=False)),
    Column("review_state", String(20), nullable=False, default="approved"),
    CheckConstraint("review_state IN ('draft', 'approved')"),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "source_id"],
        ["sources.tenant_id", "sources.base_id", "sources.id"],
    ),
)


def revision_table(name, parent, *extra):
    return tenant_table(
        name,
        Column("base_id", Uuid(as_uuid=False), nullable=False),
        Column("parent_id", Uuid(as_uuid=False), nullable=False),
        Column("version", Integer, nullable=False),
        Column("actor", String(100), nullable=False),
        Column("provenance", JSON, nullable=False, default=dict),
        UniqueConstraint("tenant_id", "base_id", "id"),
        UniqueConstraint("tenant_id", "parent_id", "version"),
        ForeignKeyConstraint(
            ["tenant_id", "base_id", "parent_id"],
            [f"{parent}.tenant_id", f"{parent}.base_id", f"{parent}.id"],
        ),
        *extra,
    )


source_revisions = revision_table(
    "source_revisions",
    "sources",
    Column("text", Text, nullable=False),
    Column("source_url", Text),
    Column("original_key", Text),
    Column("original_sha256", String(64)),
    Column("filename", String(200)),
    Column("media_type", String(100)),
)
entry_revisions = revision_table(
    "entry_revisions",
    "knowledge_entries",
    Column("question", Text, nullable=False),
    Column("answer", Text, nullable=False),
    Column("source_revision_id", Uuid(as_uuid=False)),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "source_revision_id"],
        ["source_revisions.tenant_id", "source_revisions.base_id", "source_revisions.id"],
    ),
)
projections = tenant_table(
    "index_projections",
    Column("base_id", Uuid(as_uuid=False), nullable=False),
    Column("kind", String(10), nullable=False),
    Column("dataset_id", String(100)),
    Column("epoch", Integer, nullable=False, default=1),
    CheckConstraint("kind IN ('faq', 'document')"),
    ForeignKeyConstraint(
        ["tenant_id", "base_id"], ["knowledge_bases.tenant_id", "knowledge_bases.id"]
    ),
    UniqueConstraint("tenant_id", "base_id", "kind"),
    UniqueConstraint("tenant_id", "base_id", "id"),
)
bindings = tenant_table(
    "index_bindings",
    Column("base_id", Uuid(as_uuid=False), nullable=False),
    Column("projection_id", Uuid(as_uuid=False), nullable=False),
    Column("entry_revision_id", Uuid(as_uuid=False)),
    Column("source_revision_id", Uuid(as_uuid=False)),
    Column("epoch", Integer, nullable=False),
    Column("document_id", String(100)),
    Column("batch_id", String(100)),
    Column("index_started_at", DateTime(timezone=True)),
    Column("segment_ids", JSON, nullable=False, default=list),
    Column("state", String(20), nullable=False, default="pending"),
    CheckConstraint("state IN ('pending', 'indexing', 'ready', 'retired')"),
    CheckConstraint("(entry_revision_id IS NULL) <> (source_revision_id IS NULL)"),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "projection_id"],
        ["index_projections.tenant_id", "index_projections.base_id", "index_projections.id"],
    ),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "entry_revision_id"],
        ["entry_revisions.tenant_id", "entry_revisions.base_id", "entry_revisions.id"],
    ),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "source_revision_id"],
        ["source_revisions.tenant_id", "source_revisions.base_id", "source_revisions.id"],
    ),
    UniqueConstraint("projection_id", "epoch", "entry_revision_id"),
    UniqueConstraint("projection_id", "epoch", "source_revision_id"),
    UniqueConstraint("projection_id", "document_id"),
)
jobs = tenant_table(
    "index_jobs",
    Column("base_id", Uuid(as_uuid=False), nullable=False),
    Column("projection_id", Uuid(as_uuid=False), nullable=False),
    Column("entry_id", Uuid(as_uuid=False)),
    Column("source_id", Uuid(as_uuid=False)),
    Column("generation", Integer, nullable=False),
    Column("epoch", Integer, nullable=False),
    Column("state", String(20), nullable=False, default="pending"),
    Column("attempts", Integer, nullable=False, default=0),
    Column("available_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
    Column("last_error", String(100)),
    CheckConstraint("state IN ('pending', 'done', 'failed', 'superseded')"),
    CheckConstraint("(entry_id IS NULL) <> (source_id IS NULL)"),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "projection_id"],
        ["index_projections.tenant_id", "index_projections.base_id", "index_projections.id"],
    ),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "entry_id"],
        ["knowledge_entries.tenant_id", "knowledge_entries.base_id", "knowledge_entries.id"],
    ),
    ForeignKeyConstraint(
        ["tenant_id", "base_id", "source_id"],
        ["sources.tenant_id", "sources.base_id", "sources.id"],
    ),
    UniqueConstraint("projection_id", "epoch", "entry_id", "generation"),
    UniqueConstraint("projection_id", "epoch", "source_id", "generation"),
)
Index("index_jobs_due", jobs.c.state, jobs.c.available_at)
Index("entries_by_base", entries.c.tenant_id, entries.c.base_id)
Index("sources_by_base", sources.c.tenant_id, sources.c.base_id)
