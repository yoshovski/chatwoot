import hashlib
import signal
import time
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, text, update

from cwai import schema as s
from cwai.config import settings
from cwai.db import engine
from cwai.dify import Dify, ProjectionError
from cwai.store import CONTENT, add, eligible, owned, rebuild_projection, revision
from cwai.workspace import connection

POLL_SECONDS = 5
MAX_ATTEMPTS = 8
INDEX_TIMEOUT_SECONDS = 1800


def process(conn, job, remote):
    projection = owned(conn, s.projections, job["tenant_id"], job["projection_id"], lock=True)
    kind = projection["kind"]
    table, revisions, item_key, revision_key = CONTENT[kind]
    item = owned(conn, table, job["tenant_id"], job[item_key])
    base = owned(conn, s.bases, job["tenant_id"], item["base_id"])
    if job["generation"] != item["generation"] or job["epoch"] != projection["epoch"]:
        return "superseded"
    active = eligible(conn, kind, item, base)
    if not active and projection["dataset_id"] is None:
        return "done"
    dataset_id = remote.dataset(projection)
    if dataset_id != projection["dataset_id"]:
        # New dataset means every previous remote mapping is stale. Existing
        # canonical revisions/enabled flags are untouched and all items are queued.
        old_dataset = projection["dataset_id"]
        conn.execute(
            update(s.projections)
            .where(s.projections.c.id == projection["id"])
            .values(
                dataset_id=dataset_id,
            )
        )
        if old_dataset:
            conn.execute(
                update(s.bindings)
                .where(s.bindings.c.projection_id == projection["id"])
                .values(
                    state="retired",
                    document_id=None,
                    batch_id=None,
                )
            )
            # Repair jobs use a new epoch so completed jobs can be replayed.
            rebuild_projection(conn, dict(projection), dataset_id=dataset_id)
            return "superseded"
        # Commit the dataset mapping before any document creation.
        return "pending"
    rev = revision(conn, kind, item)
    item_revision_ids = select(revisions.c.id).where(
        revisions.c.tenant_id == job["tenant_id"],
        revisions.c.parent_id == item["id"],
    )
    existing = (
        conn.execute(
            select(s.bindings).where(
                s.bindings.c.projection_id == projection["id"],
                s.bindings.c[revision_key].in_(item_revision_ids),
                s.bindings.c.state != "retired",
            )
        )
        .mappings()
        .all()
    )
    current = None
    for binding in existing:
        if (
            active
            and binding[revision_key] == rev["id"]
            and binding["epoch"] == projection["epoch"]
        ):
            current = dict(binding)
        else:
            if binding["document_id"]:
                remote.delete_document(dataset_id, binding["document_id"])
            conn.execute(
                update(s.bindings)
                .where(s.bindings.c.id == binding["id"])
                .values(
                    state="retired",
                    document_id=None,
                    batch_id=None,
                )
            )
    if not active:
        return "done"
    if current is None:
        # The binding ID must be committed before POST so crash recovery can
        # discover the remote document by its stable name.
        retired = (
            conn.execute(
                select(s.bindings).where(
                    s.bindings.c.projection_id == projection["id"],
                    s.bindings.c.epoch == projection["epoch"],
                    s.bindings.c[revision_key] == rev["id"],
                )
            )
            .mappings()
            .one_or_none()
        )
        if retired:
            conn.execute(
                update(s.bindings)
                .where(s.bindings.c.id == retired["id"])
                .values(
                    state="pending",
                    segment_ids=[],
                )
            )
        else:
            add(
                conn,
                s.bindings,
                tenant_id=job["tenant_id"],
                base_id=item["base_id"],
                projection_id=projection["id"],
                epoch=projection["epoch"],
                **{revision_key: rev["id"]},
            )
        return "pending"
    if current["document_id"] is None:
        content = (
            f"Question:\n{rev['question']}\n\nAnswer:\n{rev['answer']}"
            if kind == "faq"
            else rev["text"]
        )
        document_id, batch_id = remote.document(dataset_id, current, content)
        conn.execute(
            update(s.bindings)
            .where(s.bindings.c.id == current["id"])
            .values(
                document_id=document_id,
                batch_id=batch_id,
                state="indexing",
                index_started_at=datetime.now(UTC),
            )
        )
        return "pending"
    try:
        segments = remote.ready_segments(dataset_id, current)
    except ProjectionError as error:
        if str(error) in {"dify_not_found", "dify_document_missing"}:
            conn.execute(
                update(s.bindings)
                .where(s.bindings.c.id == current["id"])
                .values(
                    document_id=None,
                    batch_id=None,
                    state="pending",
                    segment_ids=[],
                )
            )
            return "pending"
        if str(error) == "dify_indexing_failed":
            remote.delete_document(dataset_id, current["document_id"])
        raise
    if segments is None:
        if (
            datetime.now(UTC) - current["index_started_at"]
        ).total_seconds() > INDEX_TIMEOUT_SECONDS:
            remote.delete_document(dataset_id, current["document_id"])
            raise ProjectionError("dify_indexing_timeout")
        return "pending"
    conn.execute(
        update(s.bindings)
        .where(s.bindings.c.id == current["id"])
        .values(
            state="ready",
            segment_ids=segments,
        )
    )
    return "done"


def tick() -> bool:
    if not settings().enabled:
        raise RuntimeError("CWAI_ENABLED must be true for workers")
    with engine().begin() as conn:
        # Advisory projection locks prevent concurrent provisioning/reconciliation
        # across worker processes. Transaction locks release on a killed worker.
        candidates = (
            conn.execute(
                select(s.jobs.c.id, s.jobs.c.projection_id)
                .where(
                    s.jobs.c.state == "pending",
                    s.jobs.c.available_at <= datetime.now(UTC),
                )
                .order_by(s.jobs.c.available_at)
                .limit(100)
            )
            .mappings()
            .all()
        )
        for candidate in candidates:
            lock_id = int.from_bytes(
                hashlib.sha256(candidate["projection_id"].encode()).digest()[:8], "big", signed=True
            )
            if not conn.scalar(text("SELECT pg_try_advisory_xact_lock(:id)"), {"id": lock_id}):
                continue
            row = (
                conn.execute(
                    select(s.jobs)
                    .where(
                        s.jobs.c.id == candidate["id"],
                        s.jobs.c.state == "pending",
                        s.jobs.c.available_at <= datetime.now(UTC),
                    )
                    .with_for_update(skip_locked=True)
                )
                .mappings()
                .one_or_none()
            )
            if row is None:
                continue
            job = dict(row)
            account = (
                conn.execute(select(s.accounts).where(s.accounts.c.id == job["tenant_id"]))
                .mappings()
                .one()
            )
            if not account["enabled"]:
                continue
            config = connection(account["credential_ref"])
            try:
                with conn.begin_nested(), Dify(config) as remote:
                    state = process(conn, job, remote)
                values = {
                    "state": state,
                    "last_error": None,
                    "available_at": datetime.now(UTC) + timedelta(seconds=POLL_SECONDS),
                }
            except ProjectionError as error:
                attempts = job["attempts"] + 1
                values = {
                    "attempts": attempts,
                    "last_error": str(error),
                    "state": "failed" if attempts >= MAX_ATTEMPTS else "pending",
                    "available_at": datetime.now(UTC) + timedelta(seconds=min(300, 2**attempts)),
                }
            conn.execute(update(s.jobs).where(s.jobs.c.id == job["id"]).values(**values))
            return True
    return False


def main():
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    while not stopping:
        if not tick():
            time.sleep(1)


if __name__ == "__main__":
    main()
