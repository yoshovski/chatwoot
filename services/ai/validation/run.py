"""Executable acceptance run against a disposable PostgreSQL database and lab Dify.

Set CWAI_VALIDATION_ALLOW=true. Mode fixture exercises faults; mode live uses only
new service-owned datasets and synthetic records. No existing dataset is imported.
"""

import base64
import csv
import io
import json
import os
import subprocess
import sys
import time
import zipfile
from datetime import UTC, datetime
from uuid import uuid4

import httpx
import jwt
from fastapi.testclient import TestClient
from sqlalchemy import insert, select, update
from sqlalchemy.exc import IntegrityError, ProgrammingError

from cwai import schema as s
from cwai.api import PREFIX, app
from cwai.config import settings
from cwai.db import engine
from cwai.dify import Dify
from cwai.worker import tick

if os.environ.get("CWAI_VALIDATION_ALLOW") != "true":
    raise RuntimeError("Acceptance writes require an explicitly disposable validation database")
mode = sys.argv[1] if len(sys.argv) > 1 else "fixture"
config = settings()
account_a = int(time.time())
account_b = account_a + 1
refs = list(config.dify_connections)
ref_a = "fixture-a" if mode == "fixture" else refs[0]
ref_b = "fixture-b" if mode == "fixture" else refs[0]
with engine().begin() as conn:
    tenant_a = conn.execute(
        insert(s.accounts)
        .values(
            installation_id=config.installation_id,
            account_id=account_a,
            credential_ref=ref_a,
            enabled=True,
        )
        .returning(s.accounts.c.id)
    ).scalar_one()
    tenant_b = conn.execute(
        insert(s.accounts)
        .values(
            installation_id=config.installation_id,
            account_id=account_b,
            credential_ref=ref_b,
            enabled=True,
        )
        .returning(s.accounts.c.id)
    ).scalar_one()
client = TestClient(app)
passed = []


def token(account=account_a, action="knowledge:read", **overrides):
    now = int(time.time())
    claims = {
        "iss": config.installation_id,
        "aud": config.audience,
        "sub": "lab-editor",
        "account_id": account,
        "action": action,
        "iat": now,
        "nbf": now,
        "exp": now + 60,
    }
    claims.update(overrides)
    return jwt.encode(claims, config.signing_key.get_secret_value(), algorithm="HS256")


def request(method, path, body=None, account=account_a, expected=200, action=None):
    if action is None:
        action = (
            "knowledge:read"
            if method == "GET"
            or path.endswith(("/retrieve", "/citations/validate", "/csv/preview"))
            else "knowledge:write"
        )
    result = client.request(
        method,
        PREFIX + path,
        json=body,
        headers={"Authorization": "Bearer " + token(account, action)},
    )
    assert result.status_code == expected, (method, path, result.status_code, result.text)
    if expected == 204:
        return None
    return result.json()


def due():
    with engine().begin() as conn:
        conn.execute(
            update(s.jobs)
            .where(s.jobs.c.tenant_id.in_([tenant_a, tenant_b]))
            .values(
                available_at=datetime.now(UTC),
            )
        )


def drain(timeout=180):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        due()
        worked = tick()
        with engine().connect() as conn:
            jobs = (
                conn.execute(
                    select(s.jobs).where(
                        s.jobs.c.tenant_id.in_([tenant_a, tenant_b]),
                        s.jobs.c.state.in_(["pending", "failed"]),
                    )
                )
                .mappings()
                .all()
            )
        failures = [j for j in jobs if j["state"] == "failed"]
        assert not failures, [(j["id"], j["last_error"]) for j in failures]
        if not jobs:
            return
        if mode == "live" or not worked:
            time.sleep(1)
    raise AssertionError("Projection did not finish in time")


def check(name):
    passed.append(name)
    print("PASS:", name, flush=True)


assert client.get(PREFIX + "/bases").status_code == 401
for claims in (
    {"aud": "other"},
    {"iss": "other"},
    {"exp": int(time.time()) - 1},
    {"exp": int(time.time()) + 120},
    {"account_id": str(account_a)},
    {"sub": ""},
    {"action": "admin"},
):
    assert (
        client.get(
            PREFIX + "/bases", headers={"Authorization": "Bearer " + token(**claims)}
        ).status_code
        == 401
    )
request("POST", "/bases", {"name": "Denied"}, expected=403, action="knowledge:read")
request("GET", "/bases", account=account_b + 1, expected=403)
check("signed account, actor, audience, action and lifetime enforcement")

base = request("POST", "/bases", {"name": "Synthetic acceptance FAQ"}, expected=201)
base_b = request("POST", "/bases", {"name": "Other account"}, account=account_b, expected=201)
bid = base["id"]
request("GET", f"/bases/{bid}", account=account_b, expected=404)
for body in (
    {"name": "x", "tenant_id": tenant_b},
    {"name": "x", "credential_ref": ref_b},
    {"name": 12},
    {"name": "x", "dataset_id": "forged"},
):
    request("POST", "/bases", body, expected=422)
agent = request("POST", "/agents", {"chatwoot_agent_bot_id": 100001}, expected=201)
request("PUT", f"/agents/{agent['id']}/bases/{bid}", expected=204)
request("PUT", f"/agents/{agent['id']}/bases/{bid}", expected=204)
request("PUT", f"/agents/{agent['id']}/bases/{base_b['id']}", expected=404)
request("PUT", f"/agents/{agent['id']}/bases/{bid}", account=account_b, expected=404)
agent_b = request(
    "POST", "/agents", {"chatwoot_agent_bot_id": 100002}, account=account_b, expected=201
)
try:
    with engine().begin() as conn:
        conn.execute(
            insert(s.attachments).values(tenant_id=tenant_b, agent_id=agent_b["id"], base_id=bid)
        )
except IntegrityError:
    pass
else:
    raise AssertionError("Database allowed a cross-account attachment")
check("same-account attachments, forged IDs/credentials and compound database constraints")

question = "  What is the Ω policy?\nExact question  "
answer = "Answer with  double spaces\r\nhttps://example.test/help?q=1&x=2\n  Final line  "
entry = request(
    "POST", f"/bases/{bid}/entries", {"question": question, "answer": answer}, expected=201
)
eid = entry["id"]
assert entry["revision"]["question"] == question and entry["revision"]["answer"] == answer
assert entry["index_status"] == "processing"
request("PATCH", f"/entries/{eid}/state", {"enabled": "false"}, expected=422)
request(
    "POST",
    f"/bases/{bid}/entries",
    {"question": question, "answer": answer, "account_id": account_b},
    expected=422,
)
original = b"Synthetic original\x00\xff\n"
source = request(
    "POST",
    f"/bases/{bid}/sources",
    {
        "name": "Manual.pdf",
        "text": "The document says exactly this.",
        "original_base64": base64.b64encode(original).decode(),
        "filename": "manual.pdf",
        "media_type": "application/pdf",
        "provenance": {"page": 1},
    },
    expected=201,
)
sid = source["id"]
srid = source["revision"]["id"]
r = client.get(
    PREFIX + f"/source-revisions/{srid}/original", headers={"Authorization": "Bearer " + token()}
)
assert r.content == original
request("GET", f"/source-revisions/{srid}/original", account=account_b, expected=404)
try:
    with engine().begin() as conn:
        conn.execute(
            update(s.entry_revisions)
            .where(s.entry_revisions.c.id == entry["revision"]["id"])
            .values(answer="overwrite")
        )
except ProgrammingError:
    pass
else:
    raise AssertionError("Canonical revision was mutable")
check("verbatim Q&A, private originals, strict input and immutable revision history")

if mode == "fixture":
    # Commit dataset and binding IDs, then kill the worker inside its remote create.
    for _ in range(4):
        due()
        tick()
    due()
    code = """import os
from cwai.dify import Dify
from cwai.worker import tick
original = Dify.document
def killed(self, *args):
    original(self, *args)
    os._exit(9)
Dify.document = killed
import time
while True:
    tick()
    time.sleep(0.1)
"""
    killed = subprocess.run([sys.executable, "-c", code], check=False, timeout=30)
    assert killed.returncode == 9
    check("worker killed after remote acceptance before local commit")
drain()
records = request("POST", f"/bases/{bid}/retrieve", {"query": question})["records"]
faq = next(r for r in records if r["record_id"] == eid)
assert faq["question"] == question and faq["answer"] == answer
binding_id = faq["binding_id"]
request("POST", f"/bases/{bid}/citations/validate", {"binding_ids": [binding_id]})
check("confirmed indexing, restart recovery and canonical retrieval/citation mapping")

request("PATCH", f"/entries/{eid}/state", {"enabled": False})
records = request("POST", f"/bases/{bid}/retrieve", {"query": question})["records"]
assert all(r["record_id"] != eid for r in records)
request("POST", f"/bases/{bid}/citations/validate", {"binding_ids": [binding_id]}, expected=409)
drain()
request("PATCH", f"/entries/{eid}/state", {"enabled": True})
drain()
new_answer = "  Edited Ω answer, preserved verbatim.\n"
request(
    "PUT", f"/entries/{eid}", {"question": question, "answer": new_answer, "expected_version": 1}
)
request(
    "PUT",
    f"/entries/{eid}",
    {"question": question, "answer": "stale overwrite", "expected_version": 1},
    expected=409,
)
request("POST", f"/bases/{bid}/citations/validate", {"binding_ids": [binding_id]}, expected=409)
assert all(
    r["record_id"] != eid
    for r in request("POST", f"/bases/{bid}/retrieve", {"query": question})["records"]
)
drain()
history = request("GET", f"/entries/{eid}/revisions")
assert [r["answer"] for r in history] == [answer, new_answer]
request("PATCH", f"/sources/{sid}/state", {"enabled": False})
request("POST", f"/bases/{bid}/rebuild", expected=202)
drain()
assert (
    next(
        r
        for r in request("POST", f"/bases/{bid}/retrieve", {"query": question})["records"]
        if r["record_id"] == eid
    )["answer"]
    == new_answer
)
assert not next(r for r in request("GET", f"/bases/{bid}/sources") if r["id"] == sid)["enabled"]
check("immediate disable/stale-citation rejection, optimistic edits and rebuild preservation")

if mode == "fixture":
    # Accepted POST whose acknowledgement fails is found by stable binding ID.
    connection = config.dify_connections[ref_a]
    control_url = connection.url.removesuffix("/v1") + "/control"
    httpx.post(control_url, json={"fail_after_create": 1}).raise_for_status()
    lost = request(
        "POST", f"/bases/{bid}/entries", {"question": "Ack?", "answer": "Kept"}, expected=201
    )
    drain()
    with engine().connect() as conn:
        projection = (
            conn.execute(
                select(s.projections).where(
                    s.projections.c.base_id == bid, s.projections.c.kind == "faq"
                )
            )
            .mappings()
            .one()
        )
    with Dify(connection) as remote:
        docs = list(remote.pages(f"datasets/{projection['dataset_id']}/documents"))
    assert len(docs) == 2, "Lost acknowledgement created duplicate remote documents"
    httpx.post(control_url, json={"fail_requests": 100}).raise_for_status()
    failed = request(
        "POST",
        f"/bases/{bid}/entries",
        {"question": "Failure?", "answer": "Retry me"},
        expected=201,
    )
    for _ in range(10):
        due()
        tick()
    failed_job = next(
        j for j in request("GET", f"/bases/{bid}/jobs") if j["entry_id"] == failed["id"]
    )
    assert failed_job["state"] == "failed" and failed_job["last_error"] == "dify_http_503"
    httpx.post(control_url, json={}).raise_for_status()
    request("POST", f"/jobs/{failed_job['id']}/retry", expected=202)
    drain()
    with Dify(connection) as remote:
        remote.request("DELETE", f"datasets/{projection['dataset_id']}")
    request("POST", f"/bases/{bid}/rebuild", expected=202)
    drain()
    assert any(
        r["record_id"] == lost["id"]
        for r in request("POST", f"/bases/{bid}/retrieve", {"query": "Ack?"})["records"]
    )
    check("lost acknowledgements, bounded failure/retry and deleted-dataset repair")

# Reviewed generated drafts and source-level revocation share the canonical gate.
derived = request(
    "POST",
    f"/bases/{bid}/entries",
    {
        "question": "Derived policy?",
        "answer": "Grounded draft",
        "source_id": sid,
        "source_revision_id": srid,
        "review_state": "draft",
        "provenance": {"page": 1},
    },
    expected=201,
)
assert derived["index_status"] == "needs_review"
drain()
request("PATCH", f"/sources/{sid}/state", {"enabled": True})
request("PATCH", f"/entries/{derived['id']}/review", {"review_state": "approved"})
drain()
assert any(
    r["record_id"] == derived["id"]
    for r in request("POST", f"/bases/{bid}/retrieve", {"query": "Derived policy?", "top_k": 20})[
        "records"
    ]
)
request("PATCH", f"/sources/{sid}/state", {"enabled": False})
assert all(
    r["record_id"] not in {sid, derived["id"]}
    for r in request("POST", f"/bases/{bid}/retrieve", {"query": "Derived policy?", "top_k": 20})[
        "records"
    ]
)
request(
    "PUT",
    f"/sources/{sid}",
    {"name": "Changed.pdf", "text": "Edited extracted content.", "expected_version": 1},
)
source_history = request("GET", f"/sources/{sid}/revisions")
assert (
    len(source_history) == 2
    and source_history[1]["original_sha256"] == source_history[0]["original_sha256"]
)
request("POST", f"/bases/{bid}/rebuild", expected=202)
drain()
assert not next(r for r in request("GET", f"/bases/{bid}/sources") if r["id"] == sid)["enabled"]
check("draft review, source-level revocation and original preservation across source revisions")

request("PATCH", f"/bases/{bid}", {"enabled": False})
assert request("POST", f"/bases/{bid}/retrieve", {"query": question})["records"] == []
request("PATCH", f"/bases/{bid}", {"enabled": True})
drain()
check("base disable/re-enable and original records survive all indexing operations")
# CWAI-3 portability works from canonical rows, independent of remote indexing.
exact = request(
    "POST",
    f"/bases/{bid}/entries",
    {
        "question": "  CSV naïve?\nsecond line  ",
        "answer": '=exact,"answer"\r\n with spaces  ',
        "review_state": "draft",
        "provenance": {"origin": "csv-lab", "page": 7},
    },
    expected=201,
)
request("PATCH", f"/entries/{exact['id']}/state", {"enabled": False})
snapshot = request("GET", f"/bases/{bid}/entries")
headers = {"Authorization": "Bearer " + token()}
exported = client.get(PREFIX + f"/bases/{bid}/csv", headers=headers)
assert exported.status_code == 200 and exported.headers["content-type"].startswith("text/csv")
rows = list(csv.DictReader(io.StringIO(exported.text, newline="")))
row = next(row for row in rows if row["id"] == exact["id"])
assert (
    row["question"] == exact["revision"]["question"]
    and row["answer"] == exact["revision"]["answer"]
)
assert row["enabled"] == "false" and row["review_state"] == "draft"
previewed = request(
    "POST", f"/bases/{bid}/csv/preview", {"csv": exported.text}, action="knowledge:read"
)
assert previewed["valid"] and len(previewed["rows"]) == len(snapshot)
counts = request("POST", f"/bases/{bid}/csv/import", {"csv": exported.text})
assert counts == {"created": 0, "updated": 0, "unchanged": len(snapshot)}
assert request("GET", f"/bases/{bid}/entries") == snapshot
check("CSV round-trip preserves exact wording, IDs, versions and state")

bad_csv = "question,answer,enabled\nGood?,Good,true\nBad?,Bad,yes\n"
assert not request("POST", f"/bases/{bid}/csv/preview", {"csv": bad_csv}, action="knowledge:read")[
    "valid"
]
request("POST", f"/bases/{bid}/csv/import", {"csv": bad_csv}, expected=422)
request("POST", f"/bases/{bid}/csv/import", {"csv": exported.text}, account=account_b, expected=404)
assert request("GET", f"/bases/{bid}/entries") == snapshot
other = request("POST", "/bases", {"name": "CSV isolation"}, account=account_b, expected=201)
assert not request(
    "POST", f"/bases/{other['id']}/csv/preview", {"csv": exported.text}, account=account_b
)["valid"]
request(
    "POST",
    f"/bases/{other['id']}/csv/import",
    {"csv": exported.text},
    account=account_b,
    expected=422,
)
request(
    "POST",
    f"/bases/{bid}/csv/preview",
    {"csv": "question,answer,tenant_id\nQ,A,other"},
    expected=422,
)
request(
    "POST", f"/bases/{bid}/csv/preview", {"csv": "question,question,answer\nQ,Q,A"}, expected=422
)
request(
    "POST",
    f"/bases/{bid}/csv/import",
    {"csv": "question,answer\nQ,A"},
    expected=403,
    action="knowledge:read",
)
check("CSV preview is read-only; invalid and unauthorized imports never write partial rows")

# New explicit IDs are retained. Stale revisions invalidate the entire import.
new_id = str(uuid4())
new_csv = (
    f"id,version,question,answer,enabled,review_state\n{new_id},3,Imported?,Exact,false,draft\n"
)
request("POST", f"/bases/{bid}/csv/import", {"csv": new_csv})
created = next(row for row in request("GET", f"/bases/{bid}/entries") if row["id"] == new_id)
assert created["version"] == 3 and not created["enabled"] and created["review_state"] == "draft"
request(
    "PUT", f"/entries/{new_id}", {"question": "Edited?", "answer": "New", "expected_version": 3}
)
request("POST", f"/bases/{bid}/csv/import", {"csv": new_csv}, expected=422)
check("CSV creates portable IDs and rejects stale exported versions")

archive_response = client.get(PREFIX + f"/bases/{bid}/export", headers=headers)
assert (
    archive_response.status_code == 200
    and archive_response.headers["content-type"] == "application/zip"
)
with zipfile.ZipFile(io.BytesIO(archive_response.content)) as archive:
    manifest = json.loads(archive.read("manifest.json"))
    assert manifest["schema_version"] == 1 and manifest["base"]["id"] == bid
    source_revs = [r for r in manifest["source_revisions"] if r["parent_id"] == sid]
    assert len(source_revs) == 2
    assert all(
        archive.read(r["original_file"]) == b"Synthetic original\x00\xff\n" for r in source_revs
    )
    assert any(
        r["provenance"] == {"origin": "csv-lab", "page": 7} for r in manifest["entry_revisions"]
    )
    assert archive.read("faqs.csv").decode("utf-8").startswith("id,version,question,answer")
    forbidden = {
        "tenant_id",
        "credential_ref",
        "original_key",
        "dataset_id",
        "document_id",
        "batch_id",
        "segment_ids",
        "projection_id",
        "epoch",
    }

    def check_keys(value):
        if isinstance(value, dict):
            assert not forbidden.intersection(value)
            for child in value.values():
                check_keys(child)
        elif isinstance(value, list):
            for child in value:
                check_keys(child)

    check_keys(manifest)
summary = request("GET", f"/bases/{bid}")
assert (
    summary["faq_count"] == len(request("GET", f"/bases/{bid}/entries"))
    and summary["source_count"] == 1
)
assert summary["index_status"] in {"ready", "processing"}
check("portable ZIP preserves provenance and originals without private paths or remote mappings")

print(
    f"ACCEPTANCE {mode}: {len(passed)} groups passed; synthetic accounts {account_a}, {account_b}"
)
