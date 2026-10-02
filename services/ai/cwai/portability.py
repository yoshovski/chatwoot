"""Canonical CSV exchange and portable archives; never export index credentials."""

import csv
import io
import json
import re
import zipfile
from uuid import UUID

from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder
from pydantic import ValidationError
from sqlalchemy import select

from cwai import schema as s
from cwai.config import settings
from cwai.contracts import EntryCreate
from cwai.store import add, changed, create_revision, public, queue, revision, validate_source

CSV_FIELDS = (
    "id",
    "version",
    "question",
    "answer",
    "enabled",
    "review_state",
    "source_id",
    "source_revision_id",
    "provenance",
)
MAX_ROWS = 1000
MAX_CSV_BYTES = 5 * 1024 * 1024
MAX_ARCHIVE_BYTES = 100 * 1024 * 1024
csv.field_size_limit(200_000)


def preview(conn, base, content):
    if len(content.encode("utf-8")) > MAX_CSV_BYTES:
        raise HTTPException(422, "CSV must be at most 5 MiB")
    reader = csv.DictReader(io.StringIO(content.removeprefix("\ufeff"), newline=""), strict=True)
    try:
        headers = reader.fieldnames or []
        if (
            not {"question", "answer"}.issubset(headers)
            or set(headers) - set(CSV_FIELDS)
            or len(headers) != len(set(headers))
        ):
            raise HTTPException(422, "CSV requires question,answer and only documented columns")
        rows, errors, seen = [], [], set()
        for number, raw in enumerate(reader, start=2):
            if number > MAX_ROWS + 1:
                raise HTTPException(422, "CSV must contain at most 1000 records")
            try:
                if None in raw or any(value is None for value in raw.values()):
                    raise ValueError("Row must have the same number of columns as the header")
                record_id = str(UUID(raw["id"])) if raw.get("id") else None
                if record_id and record_id in seen:
                    raise ValueError("Duplicate record ID")
                seen.add(record_id) if record_id else None
                enabled = raw.get("enabled", "true")
                if enabled not in {"true", "false"}:
                    raise ValueError("enabled must be true or false")
                version = raw.get("version")
                if version and not re.fullmatch(r"[1-9][0-9]{0,8}", version):
                    raise ValueError("version must be a positive integer")
                payload = EntryCreate(
                    question=raw["question"],
                    answer=raw["answer"],
                    source_id=raw.get("source_id") or None,
                    source_revision_id=raw.get("source_revision_id") or None,
                    review_state=raw.get("review_state", "approved"),
                    provenance=json.loads(raw.get("provenance") or "{}"),
                )
                validate_source(conn, base["tenant_id"], base["id"], payload)
                existing = (
                    conn.execute(select(s.entries).where(s.entries.c.id == record_id))
                    .mappings()
                    .one_or_none()
                    if record_id
                    else None
                )
                if existing:
                    if (
                        existing["tenant_id"] != base["tenant_id"]
                        or existing["base_id"] != base["id"]
                    ):
                        raise ValueError("Record ID is unavailable in this base")
                    if not version or int(version) != existing["version"]:
                        raise ValueError("Knowledge changed; export or reload before importing")
                rows.append(
                    {
                        "row": number,
                        "id": record_id,
                        "version": int(version) if version else 1,
                        "enabled": enabled == "true",
                        "operation": "update" if existing else "create",
                        **payload.model_dump(),
                    }
                )
            except (ValueError, ValidationError, HTTPException) as error:
                message = (
                    "Source is unavailable in this base"
                    if isinstance(error, HTTPException)
                    else str(error)
                )
                errors.append({"row": number, "message": message})
    except csv.Error as error:
        raise HTTPException(422, f"Invalid CSV: {error}") from None
    if not rows and not errors:
        raise HTTPException(422, "CSV must contain at least one record")
    return {"valid": not errors, "rows": rows, "errors": errors}


def import_csv(conn, base, content, actor):
    result = preview(conn, base, content)
    if not result["valid"]:
        raise HTTPException(422, result)
    counts = {"created": 0, "updated": 0, "unchanged": 0}
    for row in result["rows"]:
        payload = EntryCreate.model_validate({key: row[key] for key in EntryCreate.model_fields})
        if row["operation"] == "create":
            values = {"id": row["id"]} if row["id"] else {}
            item = add(
                conn,
                s.entries,
                **values,
                tenant_id=base["tenant_id"],
                base_id=base["id"],
                version=row["version"],
                enabled=row["enabled"],
                source_id=payload.source_id,
                review_state=payload.review_state,
            )
            create_revision(conn, "faq", item, payload, actor)
            queue(conn, "faq", item)
            counts["created"] += 1
            continue
        item = dict(
            conn.execute(select(s.entries).where(s.entries.c.id == row["id"]).with_for_update())
            .mappings()
            .one()
        )
        old = revision(conn, "faq", item)
        content_changed = any(
            old[key] != getattr(payload, key)
            for key in ("question", "answer", "provenance", "source_revision_id")
        )
        state_changed = any(
            item[key] != row[key] for key in ("enabled", "review_state", "source_id")
        )
        if not content_changed and not state_changed:
            counts["unchanged"] += 1
            continue
        item = changed(
            conn,
            "faq",
            item,
            version=item["version"] + int(content_changed),
            enabled=row["enabled"],
            review_state=payload.review_state,
            source_id=payload.source_id,
        )
        if content_changed:
            create_revision(conn, "faq", item, payload, actor)
        counts["updated"] += 1
    return counts


def export_csv(conn, base):
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=CSV_FIELDS)
    writer.writeheader()
    for row in conn.execute(
        select(s.entries)
        .where(s.entries.c.tenant_id == base["tenant_id"], s.entries.c.base_id == base["id"])
        .order_by(s.entries.c.created_at, s.entries.c.id)
    ).mappings():
        rev = revision(conn, "faq", row)
        writer.writerow(
            {
                "id": row["id"],
                "version": row["version"],
                "enabled": str(row["enabled"]).lower(),
                "review_state": row["review_state"],
                "source_id": row["source_id"],
                "source_revision_id": rev["source_revision_id"],
                "question": rev["question"],
                "answer": rev["answer"],
                "provenance": json.dumps(rev["provenance"], ensure_ascii=False),
            }
        )
    return stream.getvalue()


def export_archive(conn, base):
    manifest = {"schema_version": 1, "base": public(base)}
    originals = {}
    total = 0
    for name, table in (
        ("entries", s.entries),
        ("entry_revisions", s.entry_revisions),
        ("sources", s.sources),
        ("source_revisions", s.source_revisions),
    ):
        records = []
        for row in conn.execute(
            select(table)
            .where(table.c.tenant_id == base["tenant_id"], table.c.base_id == base["id"])
            .order_by(table.c.created_at, table.c.id)
        ).mappings():
            record = public(dict(row))
            if name == "source_revisions" and row["original_key"]:
                archive_path = f"originals/{row['parent_id']}/{row['original_sha256']}.bin"
                record["original_file"] = archive_path
                originals[archive_path] = settings().originals_path / row["original_key"]
            records.append(record)
            total += len(json.dumps(jsonable_encoder(record), ensure_ascii=False).encode("utf-8"))
            if total > MAX_ARCHIVE_BYTES:
                raise HTTPException(422, "Portable export exceeds 100 MiB")
        manifest[name] = records
    total += sum(path.stat().st_size for path in originals.values())
    if total > MAX_ARCHIVE_BYTES:
        raise HTTPException(422, "Portable export exceeds 100 MiB")
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(
            "manifest.json", json.dumps(jsonable_encoder(manifest), ensure_ascii=False, indent=2)
        )
        archive.writestr("faqs.csv", export_csv(conn, base))
        for name, path in originals.items():
            archive.write(path, name)
    return stream.getvalue()
