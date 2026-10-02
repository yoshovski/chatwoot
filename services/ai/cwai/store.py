import base64
import hashlib
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import insert, select, update

from cwai import schema as s
from cwai.config import settings

CONTENT = {
    "faq": (s.entries, s.entry_revisions, "entry_id", "entry_revision_id"),
    "document": (s.sources, s.source_revisions, "source_id", "source_revision_id"),
}


def owned(conn, table, tenant_id, record_id, *, lock=False):
    query = select(table).where(table.c.tenant_id == tenant_id, table.c.id == str(record_id))
    if lock:
        query = query.with_for_update()
    row = conn.execute(query).mappings().one_or_none()
    if row is None:
        raise HTTPException(404, "Knowledge record not found")
    return dict(row)


def add(conn, table, **values):
    return dict(conn.execute(insert(table).values(**values).returning(table)).mappings().one())


def public(row):
    return {
        k: v
        for k, v in row.items()
        if k
        not in {
            "tenant_id",
            "original_key",
            "credential_ref",
            "dataset_id",
            "document_id",
            "batch_id",
            "segment_ids",
            "projection_id",
            "epoch",
        }
    }


def revision(conn, kind, item):
    table = CONTENT[kind][1]
    return dict(
        conn.execute(
            select(table).where(
                table.c.tenant_id == item["tenant_id"],
                table.c.parent_id == item["id"],
                table.c.version == item["version"],
            )
        )
        .mappings()
        .one()
    )


def queue(conn, kind, item):
    projection = (
        conn.execute(
            select(s.projections).where(
                s.projections.c.tenant_id == item["tenant_id"],
                s.projections.c.base_id == item["base_id"],
                s.projections.c.kind == kind,
            )
        )
        .mappings()
        .one()
    )
    add(
        conn,
        s.jobs,
        tenant_id=item["tenant_id"],
        base_id=item["base_id"],
        projection_id=projection["id"],
        epoch=projection["epoch"],
        generation=item["generation"],
        **{CONTENT[kind][2]: item["id"]},
    )


def changed(conn, kind, item, **values):
    table = CONTENT[kind][0]
    result = dict(
        conn.execute(
            update(table)
            .where(table.c.id == item["id"])
            .values(
                generation=item["generation"] + 1,
                **values,
            )
            .returning(table)
        )
        .mappings()
        .one()
    )
    queue(conn, kind, result)
    return result


def queue_base(conn, base_id, tenant_id):
    # Lock order is base -> source -> entries for all request writers.
    for kind, (table, _, _, _) in CONTENT.items():
        rows = (
            conn.execute(
                select(table)
                .where(
                    table.c.tenant_id == tenant_id,
                    table.c.base_id == base_id,
                )
                .order_by(table.c.id)
                .with_for_update()
            )
            .mappings()
            .all()
        )
        for item in rows:
            changed(conn, kind, dict(item))


def source_entries_changed(conn, source):
    rows = (
        conn.execute(
            select(s.entries)
            .where(
                s.entries.c.tenant_id == source["tenant_id"],
                s.entries.c.source_id == source["id"],
            )
            .order_by(s.entries.c.id)
            .with_for_update()
        )
        .mappings()
        .all()
    )
    for item in rows:
        changed(conn, "faq", dict(item))


def original_values(tenant_id, source_id, revision_id, payload, previous=None):
    if payload.original_base64 is None:
        return {
            k: previous[k] if previous else None
            for k in ("original_key", "original_sha256", "filename", "media_type")
        }
    data = base64.b64decode(payload.original_base64, validate=True)
    key = f"{tenant_id}/{source_id}/{revision_id}.bin"
    path = settings().originals_path / key
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.open("xb") as stream:
        stream.write(data)
    path.chmod(0o600)
    return {
        "original_key": key,
        "original_sha256": hashlib.sha256(data).hexdigest(),
        "filename": payload.filename,
        "media_type": payload.media_type,
    }


def create_revision(conn, kind, item, payload, actor, previous=None):
    values = payload.model_dump(
        exclude={
            "expected_version",
            "original_base64",
            "filename",
            "media_type",
            "name",
            "source_id",
            "review_state",
        }
    )
    revision_id = str(uuid4())
    if kind == "document":
        values.update(
            original_values(item["tenant_id"], item["id"], revision_id, payload, previous)
        )
    return add(
        conn,
        CONTENT[kind][1],
        id=revision_id,
        tenant_id=item["tenant_id"],
        base_id=item["base_id"],
        parent_id=item["id"],
        version=item["version"],
        actor=actor,
        **values,
    )


def validate_source(conn, tenant_id, base_id, payload):
    if payload.source_id is None:
        return
    source = owned(conn, s.sources, tenant_id, payload.source_id)
    source_revision = owned(conn, s.source_revisions, tenant_id, payload.source_revision_id)
    if source["base_id"] != base_id or source_revision["parent_id"] != source["id"]:
        raise HTTPException(422, "Source revision must belong to this base and source")


def eligible(conn, kind, item, base):
    if not base["enabled"] or not item["enabled"]:
        return False
    if kind == "faq":
        if item["review_state"] != "approved":
            return False
        if item["source_id"]:
            return owned(conn, s.sources, item["tenant_id"], item["source_id"])["enabled"]
    return True


def binding_content(conn, tenant_id, base_id, binding):
    # One statement takes a consistent snapshot of every eligibility condition.
    # The remote record and a previously read binding never establish authority.
    kind = owned(conn, s.projections, tenant_id, binding["projection_id"])["kind"]
    items, revisions, _, revision_key = CONTENT[kind]
    columns = [items.c.id.label("record_id"), revisions.c.id.label("revision_id")]
    columns += (
        [revisions.c.question, revisions.c.answer]
        if kind == "faq"
        else [
            revisions.c.text,
            revisions.c.source_url,
        ]
    )
    joined = s.bindings.join(s.projections, s.bindings.c.projection_id == s.projections.c.id)
    joined = joined.join(revisions, s.bindings.c[revision_key] == revisions.c.id)
    joined = joined.join(items, revisions.c.parent_id == items.c.id)
    joined = joined.join(s.bases, items.c.base_id == s.bases.c.id)
    query = (
        select(*columns)
        .select_from(joined)
        .where(
            s.bindings.c.id == binding["id"],
            s.bindings.c.tenant_id == tenant_id,
            s.bindings.c.base_id == base_id,
            s.bindings.c.state == "ready",
            s.bindings.c.epoch == s.projections.c.epoch,
            items.c.version == revisions.c.version,
            items.c.enabled.is_(True),
            s.bases.c.enabled.is_(True),
        )
    )
    if kind == "faq":
        query = query.outerjoin(s.sources, items.c.source_id == s.sources.c.id).where(
            items.c.review_state == "approved",
            (items.c.source_id.is_(None)) | s.sources.c.enabled.is_(True),
        )
    content = conn.execute(query).mappings().one_or_none()
    if content is None:
        return None
    return {"binding_id": binding["id"], "kind": kind, "base_id": base_id, **dict(content)}


def rebuild_projection(conn, projection, dataset_id=None):
    epoch = projection["epoch"] + 1
    values = {"epoch": epoch}
    if dataset_id is not None:
        values["dataset_id"] = dataset_id
    conn.execute(
        update(s.projections).where(s.projections.c.id == projection["id"]).values(**values)
    )
    table, _, key, _ = CONTENT[projection["kind"]]
    for item in (
        conn.execute(
            select(table).where(
                table.c.tenant_id == projection["tenant_id"],
                table.c.base_id == projection["base_id"],
            )
        )
        .mappings()
        .all()
    ):
        add(
            conn,
            s.jobs,
            tenant_id=projection["tenant_id"],
            base_id=projection["base_id"],
            projection_id=projection["id"],
            epoch=epoch,
            generation=item["generation"],
            **{key: item["id"]},
        )
