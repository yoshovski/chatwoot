from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.responses import JSONResponse
from sqlalchemy import delete, func, select, text, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError

from cwai import schema as s
from cwai.auth import Scope, read_scope, write_scope
from cwai.config import settings
from cwai.contracts import (
    AgentCreate,
    BaseCreate,
    BaseUpdate,
    Citations,
    CSVUpload,
    EntryCreate,
    EntryEdit,
    Retrieval,
    ReviewUpdate,
    SourceCreate,
    SourceEdit,
    StateUpdate,
)
from cwai.db import engine
from cwai.dify import Dify, ProjectionError
from cwai.knowledge_search import router as search_router
from cwai.portability import export_archive, export_csv, import_csv, preview
from cwai.store import (
    CONTENT,
    add,
    binding_content,
    changed,
    create_revision,
    eligible,
    owned,
    public,
    queue,
    queue_base,
    rebuild_projection,
    revision,
    source_entries_changed,
    validate_source,
)
from cwai.workspace import connection
from cwai.workspace import router as workspace_router

app = FastAPI(title="Chatwoot AI knowledge service", version="0.1.0")
PREFIX = "/v1/knowledge"
app.include_router(search_router)
app.include_router(workspace_router)


@app.exception_handler(ProjectionError)
def projection_error(_request, _error):
    return JSONResponse(
        {"detail": "Knowledge retrieval is temporarily unavailable"}, status_code=502
    )


@app.get("/health")
def health():
    with engine().connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok", "enabled": settings().enabled}


def item_status(conn, kind, item):
    base = owned(conn, s.bases, item["tenant_id"], item["base_id"])
    if not item["enabled"] or not base["enabled"]:
        return "disabled"
    if kind == "faq" and item["review_state"] == "draft":
        return "needs_review"
    if not eligible(conn, kind, item, base):
        return "disabled"
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
    key = CONTENT[kind][2]
    job = (
        conn.execute(
            select(s.jobs).where(
                s.jobs.c.projection_id == projection["id"],
                s.jobs.c.epoch == projection["epoch"],
                s.jobs.c[key] == item["id"],
                s.jobs.c.generation == item["generation"],
            )
        )
        .mappings()
        .one()
    )
    return {
        "done": "ready",
        "failed": "failed",
        "pending": "processing",
        "superseded": "processing",
    }[job["state"]]


def view(conn, kind, item):
    return {
        **public(item),
        "revision": public(revision(conn, kind, item)),
        "index_status": item_status(conn, kind, item),
    }


def base_summary(conn, base):
    summary = public(base)
    states = []
    for kind, (table, _, key, _) in CONTENT.items():
        scoped = (table.c.tenant_id == base["tenant_id"]) & (table.c.base_id == base["id"])
        summary["faq_count" if kind == "faq" else "source_count"] = conn.scalar(
            select(func.count()).select_from(table).where(scoped)
        )
        joined = table.join(
            s.projections,
            (s.projections.c.base_id == table.c.base_id) & (s.projections.c.kind == kind),
        ).join(
            s.jobs,
            (s.jobs.c[key] == table.c.id)
            & (s.jobs.c.generation == table.c.generation)
            & (s.jobs.c.projection_id == s.projections.c.id)
            & (s.jobs.c.epoch == s.projections.c.epoch),
        )
        query = select(s.jobs.c.state).select_from(joined).where(scoped, table.c.enabled.is_(True))
        if kind == "faq":
            query = query.outerjoin(s.sources, s.sources.c.id == table.c.source_id).where(
                table.c.review_state == "approved",
                (table.c.source_id.is_(None)) | s.sources.c.enabled.is_(True),
            )
        states.extend(conn.scalars(query.distinct()))
    summary["agent_count"] = conn.scalar(
        select(func.count())
        .select_from(s.attachments)
        .where(
            s.attachments.c.tenant_id == base["tenant_id"], s.attachments.c.base_id == base["id"]
        )
    )
    summary["index_status"] = (
        "disabled"
        if not base["enabled"]
        else "failed"
        if "failed" in states
        else "processing"
        if any(state != "done" for state in states)
        else "ready"
        if states
        else "empty"
    )
    return summary


@app.get(PREFIX + "/bases")
def list_bases(auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        return [
            base_summary(conn, dict(row))
            for row in conn.execute(
                select(s.bases)
                .where(
                    s.bases.c.tenant_id == auth.tenant_id,
                )
                .order_by(s.bases.c.created_at)
            ).mappings()
        ]


@app.post(PREFIX + "/bases", status_code=201)
def create_base(payload: BaseCreate, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        base = add(conn, s.bases, tenant_id=auth.tenant_id, name=payload.name)
        for kind in CONTENT:
            add(conn, s.projections, tenant_id=auth.tenant_id, base_id=base["id"], kind=kind)
        return public(base)


@app.get(PREFIX + "/bases/{base_id}")
def show_base(base_id: UUID, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        return base_summary(conn, owned(conn, s.bases, auth.tenant_id, base_id))


@app.patch(PREFIX + "/bases/{base_id}")
def update_base(base_id: UUID, payload: BaseUpdate, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
        values = payload.model_dump(exclude_unset=True)
        values["generation"] = base["generation"] + 1
        result = (
            conn.execute(
                update(s.bases)
                .where(s.bases.c.id == base["id"])
                .values(
                    **values,
                )
                .returning(s.bases)
            )
            .mappings()
            .one()
        )
        if "enabled" in payload.model_fields_set:
            queue_base(conn, base["id"], auth.tenant_id)
        return public(dict(result))


@app.post(PREFIX + "/bases/{base_id}/rebuild", status_code=202)
def rebuild(base_id: UUID, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
        rows = (
            conn.execute(
                select(s.projections)
                .where(
                    s.projections.c.tenant_id == auth.tenant_id,
                    s.projections.c.base_id == base["id"],
                )
                .order_by(s.projections.c.id)
                .with_for_update()
            )
            .mappings()
            .all()
        )
        for projection in rows:
            rebuild_projection(conn, dict(projection))
    return {"status": "processing"}


@app.post(PREFIX + "/agents", status_code=201)
def ensure_agent(payload: AgentCreate, auth: Scope = Depends(write_scope)):
    # Rails verifies this is an account-owned AgentBot before signing the request.
    with engine().begin() as conn:
        conn.execute(
            pg_insert(s.agents)
            .values(
                tenant_id=auth.tenant_id,
                chatwoot_agent_bot_id=payload.chatwoot_agent_bot_id,
            )
            .on_conflict_do_nothing(index_elements=["tenant_id", "chatwoot_agent_bot_id"])
        )
        row = (
            conn.execute(
                select(s.agents).where(
                    s.agents.c.tenant_id == auth.tenant_id,
                    s.agents.c.chatwoot_agent_bot_id == payload.chatwoot_agent_bot_id,
                )
            )
            .mappings()
            .one()
        )
        return public(dict(row))


@app.get(PREFIX + "/agents/{agent_id}/bases")
def agent_bases(agent_id: UUID, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        agent = owned(conn, s.agents, auth.tenant_id, agent_id)
        rows = conn.execute(
            select(s.bases)
            .join(
                s.attachments,
                (
                    (s.attachments.c.tenant_id == s.bases.c.tenant_id)
                    & (s.attachments.c.base_id == s.bases.c.id)
                ),
            )
            .where(
                s.attachments.c.tenant_id == auth.tenant_id, s.attachments.c.agent_id == agent["id"]
            )
        ).mappings()
        return [public(dict(row)) for row in rows]


@app.put(PREFIX + "/agents/{agent_id}/bases/{base_id}", status_code=204)
def attach(agent_id: UUID, base_id: UUID, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        agent = owned(conn, s.agents, auth.tenant_id, agent_id)
        base = owned(conn, s.bases, auth.tenant_id, base_id)
        conn.execute(
            pg_insert(s.attachments)
            .values(
                tenant_id=auth.tenant_id,
                agent_id=agent["id"],
                base_id=base["id"],
            )
            .on_conflict_do_nothing(index_elements=["tenant_id", "agent_id", "base_id"])
        )
    return Response(status_code=204)


@app.delete(PREFIX + "/agents/{agent_id}/bases/{base_id}", status_code=204)
def detach(agent_id: UUID, base_id: UUID, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        agent = owned(conn, s.agents, auth.tenant_id, agent_id)
        base = owned(conn, s.bases, auth.tenant_id, base_id)
        conn.execute(
            delete(s.attachments).where(
                s.attachments.c.tenant_id == auth.tenant_id,
                s.attachments.c.agent_id == agent["id"],
                s.attachments.c.base_id == base["id"],
            )
        )
    return Response(status_code=204)


@app.post(PREFIX + "/bases/{base_id}/entries", status_code=201)
def create_entry(base_id: UUID, payload: EntryCreate, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
        validate_source(conn, auth.tenant_id, base["id"], payload)
        item = add(
            conn,
            s.entries,
            tenant_id=auth.tenant_id,
            base_id=base["id"],
            source_id=payload.source_id,
            review_state=payload.review_state,
        )
        create_revision(conn, "faq", item, payload, auth.actor)
        queue(conn, "faq", item)
        return view(conn, "faq", item)


@app.post(PREFIX + "/bases/{base_id}/sources", status_code=201)
def create_source(base_id: UUID, payload: SourceCreate, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
        item = add(conn, s.sources, tenant_id=auth.tenant_id, base_id=base["id"], name=payload.name)
        create_revision(conn, "document", item, payload, auth.actor)
        queue(conn, "document", item)
        return view(conn, "document", item)


def list_items(kind):
    def handler(base_id: UUID, auth: Scope = Depends(read_scope)):
        with engine().connect() as conn:
            base = owned(conn, s.bases, auth.tenant_id, base_id)
            table = CONTENT[kind][0]
            return [
                view(conn, kind, dict(row))
                for row in conn.execute(
                    select(table)
                    .where(
                        table.c.tenant_id == auth.tenant_id,
                        table.c.base_id == base["id"],
                    )
                    .order_by(table.c.created_at)
                ).mappings()
            ]

    return handler


def item_history(kind):
    def handler(item_id: UUID, auth: Scope = Depends(read_scope)):
        with engine().connect() as conn:
            item = owned(conn, CONTENT[kind][0], auth.tenant_id, item_id)
            table = CONTENT[kind][1]
            return [
                public(dict(row))
                for row in conn.execute(
                    select(table)
                    .where(
                        table.c.tenant_id == auth.tenant_id,
                        table.c.parent_id == item["id"],
                    )
                    .order_by(table.c.version)
                ).mappings()
            ]

    return handler


def item_state(kind):
    def handler(item_id: UUID, payload: StateUpdate, auth: Scope = Depends(write_scope)):
        with engine().begin() as conn:
            item = owned(conn, CONTENT[kind][0], auth.tenant_id, item_id)
            owned(conn, s.bases, auth.tenant_id, item["base_id"], lock=True)
            item = owned(conn, CONTENT[kind][0], auth.tenant_id, item_id, lock=True)
            item = changed(conn, kind, item, enabled=payload.enabled)
            if kind == "document":
                source_entries_changed(conn, item)
            return view(conn, kind, item)

    return handler


for _kind, _path in (("faq", "entries"), ("document", "sources")):
    app.add_api_route(PREFIX + "/bases/{base_id}/" + _path, list_items(_kind), methods=["GET"])
    app.add_api_route(
        PREFIX + "/" + _path + "/{item_id}/revisions", item_history(_kind), methods=["GET"]
    )
    app.add_api_route(
        PREFIX + "/" + _path + "/{item_id}/state", item_state(_kind), methods=["PATCH"]
    )


def edit_item(conn, kind, item_id, payload, auth):
    item = owned(conn, CONTENT[kind][0], auth.tenant_id, item_id)
    owned(conn, s.bases, auth.tenant_id, item["base_id"], lock=True)
    item = owned(conn, CONTENT[kind][0], auth.tenant_id, item_id, lock=True)
    if item["version"] != payload.expected_version:
        raise HTTPException(409, "Knowledge changed; reload before saving")
    previous = revision(conn, kind, item)
    values = {"version": item["version"] + 1}
    if kind == "faq":
        validate_source(conn, auth.tenant_id, item["base_id"], payload)
        values.update(source_id=payload.source_id, review_state=payload.review_state)
    else:
        values["name"] = payload.name
    item = changed(conn, kind, item, **values)
    create_revision(conn, kind, item, payload, auth.actor, previous)
    return view(conn, kind, item)


@app.put(PREFIX + "/entries/{item_id}")
def edit_entry(item_id: UUID, payload: EntryEdit, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        return edit_item(conn, "faq", item_id, payload, auth)


@app.put(PREFIX + "/sources/{item_id}")
def edit_source(item_id: UUID, payload: SourceEdit, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        return edit_item(conn, "document", item_id, payload, auth)


@app.patch(PREFIX + "/entries/{item_id}/review")
def review_entry(item_id: UUID, payload: ReviewUpdate, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        item = owned(conn, s.entries, auth.tenant_id, item_id)
        owned(conn, s.bases, auth.tenant_id, item["base_id"], lock=True)
        item = owned(conn, s.entries, auth.tenant_id, item_id, lock=True)
        return view(conn, "faq", changed(conn, "faq", item, review_state=payload.review_state))


@app.get(PREFIX + "/source-revisions/{revision_id}/original")
def original(revision_id: UUID, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        rev = owned(conn, s.source_revisions, auth.tenant_id, revision_id)
    if rev["original_key"] is None:
        raise HTTPException(404, "Source has no original file")
    return Response(
        (settings().originals_path / rev["original_key"]).read_bytes(),
        media_type="application/octet-stream",
    )


@app.get(PREFIX + "/bases/{base_id}/jobs")
def list_jobs(base_id: UUID, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id)
        return [
            public(dict(row))
            for row in conn.execute(
                select(s.jobs)
                .where(
                    s.jobs.c.tenant_id == auth.tenant_id,
                    s.jobs.c.base_id == base["id"],
                )
                .order_by(s.jobs.c.created_at.desc())
                .limit(100)
            ).mappings()
        ]


@app.post(PREFIX + "/jobs/{job_id}/retry", status_code=202)
def retry_job(job_id: UUID, auth: Scope = Depends(write_scope)):
    with engine().begin() as conn:
        job = owned(conn, s.jobs, auth.tenant_id, job_id, lock=True)
        if job["state"] != "failed":
            raise HTTPException(422, "Only failed jobs can be retried")
        conn.execute(
            update(s.jobs)
            .where(s.jobs.c.id == job["id"])
            .values(
                state="pending",
                attempts=0,
                last_error=None,
                available_at=text("now()"),
            )
        )
    return {"status": "processing"}


@app.post(PREFIX + "/bases/{base_id}/retrieve")
def retrieve(base_id: UUID, payload: Retrieval, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id)
        if not base["enabled"]:
            return {"records": []}
        account = (
            conn.execute(select(s.accounts).where(s.accounts.c.id == auth.tenant_id))
            .mappings()
            .one()
        )
        projections = (
            conn.execute(
                select(s.projections).where(
                    s.projections.c.tenant_id == auth.tenant_id,
                    s.projections.c.base_id == base["id"],
                    s.projections.c.dataset_id.is_not(None),
                )
            )
            .mappings()
            .all()
        )
    candidates = []
    with Dify(connection(account["credential_ref"])) as remote:
        for projection in projections:
            for record in remote.retrieve(projection["dataset_id"], payload.query, payload.top_k):
                segment = record["segment"]
                candidates.append(
                    (projection["id"], segment["document_id"], segment["id"], record["score"])
                )
    accepted = {}
    # Fresh reads after network I/O exclude edits/disables/rebuilds that occurred
    # while Dify was returning stale data. No retrieval cache stores revoked content.
    with engine().connect() as conn:
        for projection_id, document_id, segment_id, score in candidates:
            binding = (
                conn.execute(
                    select(s.bindings).where(
                        s.bindings.c.tenant_id == auth.tenant_id,
                        s.bindings.c.projection_id == projection_id,
                        s.bindings.c.document_id == document_id,
                    )
                )
                .mappings()
                .one_or_none()
            )
            if binding and segment_id in binding["segment_ids"]:
                content = binding_content(conn, auth.tenant_id, base["id"], dict(binding))
                if content:
                    accepted[content["binding_id"]] = {**content, "score": score}
    return {
        "records": sorted(accepted.values(), key=lambda r: r["score"], reverse=True)[
            : payload.top_k
        ]
    }


@app.post(PREFIX + "/bases/{base_id}/citations/validate")
def validate_citations(base_id: UUID, payload: Citations, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id)
        records = []
        for binding_id in payload.binding_ids:
            try:
                UUID(binding_id)
            except ValueError:
                raise HTTPException(422, "Invalid citation ID") from None
            binding = owned(conn, s.bindings, auth.tenant_id, binding_id)
            content = binding_content(conn, auth.tenant_id, base["id"], binding)
            if content is None:
                raise HTTPException(409, "Knowledge citation is no longer current")
            records.append(content)
        return {"records": records}


@app.post(PREFIX + "/bases/{base_id}/csv/preview")
def preview_csv(base_id: UUID, payload: CSVUpload, auth: Scope = Depends(read_scope)):
    with engine().begin() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
        return preview(conn, base, payload.csv)


@app.post(PREFIX + "/bases/{base_id}/csv/import")
def upload_csv(base_id: UUID, payload: CSVUpload, auth: Scope = Depends(write_scope)):
    try:
        with engine().begin() as conn:
            base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
            return import_csv(conn, base, payload.csv, auth.actor)
    except IntegrityError:
        raise HTTPException(409, "Knowledge changed; preview again before importing") from None


@app.get(PREFIX + "/bases/{base_id}/csv")
def download_csv(base_id: UUID, auth: Scope = Depends(read_scope)):
    with engine().begin() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
        return Response(
            export_csv(conn, base),
            media_type="text/csv",
            headers={"Content-Disposition": 'attachment; filename="faqs.csv"'},
        )


@app.get(PREFIX + "/bases/{base_id}/export")
def download_archive(base_id: UUID, auth: Scope = Depends(read_scope)):
    with engine().begin() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id, lock=True)
        return Response(
            export_archive(conn, base),
            media_type="application/zip",
            headers={"Content-Disposition": 'attachment; filename="knowledge.zip"'},
        )


@app.get(PREFIX + "/bases/{base_id}/agents")
def base_agents(base_id: UUID, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        base = owned(conn, s.bases, auth.tenant_id, base_id)
        return [
            public(dict(row))
            for row in conn.execute(
                select(s.agents)
                .join(s.attachments, s.agents.c.id == s.attachments.c.agent_id)
                .where(
                    s.attachments.c.tenant_id == auth.tenant_id,
                    s.attachments.c.base_id == base["id"],
                )
            ).mappings()
        ]
