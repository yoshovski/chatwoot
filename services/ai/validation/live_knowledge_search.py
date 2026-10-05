"""Signed endpoint acceptance using only newly created synthetic Dify datasets."""

import os
import time

import httpx
import jwt
from fastapi.testclient import TestClient
from sqlalchemy import delete, insert

from cwai import schema as s
from cwai.api import app
from cwai.config import settings
from cwai.db import engine
from cwai.dify import Dify


def main():
    if os.environ.get("CWAI_VALIDATION_ALLOW") != "true":
        raise RuntimeError("Explicit lab validation authorization is required")
    config = settings()
    reference = os.environ["CWAI_VALIDATION_CREDENTIAL_REF"]
    connection = config.dify_connections[reference]
    account_id = int(time.time() * 1000)
    with engine().begin() as conn:
        tenant_id = conn.execute(
            insert(s.accounts)
            .values(
                installation_id=config.installation_id,
                account_id=account_id,
                credential_ref=reference,
                enabled=True,
            )
            .returning(s.accounts.c.id)
        ).scalar_one()
    client = (
        httpx.Client(base_url=os.environ["CWAI_VALIDATION_API_URL"], timeout=30)
        if os.environ.get("CWAI_VALIDATION_API_URL")
        else TestClient(app)
    )
    datasets = []
    question = "What are the Cobalt Compass shop opening hours, delivery and product details?"
    answer = (
        "The Cobalt Compass shop is open 24/7. Delivery takes two business days. "
        "The cobalt compass is water resistant."
    )
    # Only one part of the long source answers the query; the rest must not be returned wholesale.
    document_text = (
        "Cobalt Compass shop guide. "
        + answer
        + "\n\n"
        + "\n\n".join(
            f"Maintenance note {n}: Archive test fixtures carefully. "
            "Synthetic violet telescope records "
            "have separate revision identifiers and a laboratory-only retention schedule."
            for n in range(100)
        )
    )
    bodies = {
        "faq": f"Question: {question}\nAnswer: {answer}",
        "document": document_text,
        "catalog": "Product: Cobalt compass\nProduct handle: cobalt-compass\n" + answer,
    }
    try:
        with Dify(connection) as remote:
            for kind, content in bodies.items():
                dataset_id = remote.request(
                    "POST",
                    "datasets",
                    json={
                        "name": f"Synthetic T5 {kind} {account_id}",
                        "permission": "only_me",
                        "indexing_technique": "high_quality",
                        "embedding_model": connection.embedding_model,
                        "embedding_model_provider": connection.embedding_provider,
                    },
                )["id"]
                datasets.append({"dataset_id": dataset_id, "kind": kind, "limit": 6})
                result = remote.request(
                    "POST",
                    f"datasets/{dataset_id}/document/create-by-text",
                    json={
                        "name": f"Synthetic {kind}",
                        "text": content,
                        "indexing_technique": "high_quality",
                        "doc_form": "qa_model" if kind == "faq" else "text_model",
                        "process_rule": {
                            "mode": "custom",
                            "rules": {
                                "pre_processing_rules": [],
                                "segmentation": {"separator": "\n\n", "max_tokens": 500},
                            },
                        },
                    },
                )
                document_id = result["document"]["id"]
                deadline = time.monotonic() + 180
                while True:
                    document = remote.request(
                        "GET", f"datasets/{dataset_id}/documents/{document_id}"
                    )
                    if document["indexing_status"] == "completed":
                        break
                    if document["indexing_status"] == "error" or time.monotonic() > deadline:
                        raise AssertionError("Synthetic document indexing failed")
                    time.sleep(2)
                if kind == "faq":
                    for segment in remote.pages(
                        f"datasets/{dataset_id}/documents/{document_id}/segments"
                    ):
                        remote.request(
                            "DELETE",
                            f"datasets/{dataset_id}/documents/{document_id}/segments/{segment['id']}",
                        )
                    remote.request(
                        "POST",
                        f"datasets/{dataset_id}/documents/{document_id}/segments",
                        json={"segments": [{"content": question, "answer": answer}]},
                    )

            now = int(time.time())
            claims = {
                "iss": config.installation_id,
                "aud": config.audience,
                "sub": "synthetic-t5",
                "account_id": account_id,
                "action": "knowledge:read",
                "iat": now,
                "nbf": now,
                "exp": now + 60,
            }
            headers = {
                "Authorization": "Bearer "
                + jwt.encode(claims, config.signing_key.get_secret_value(), algorithm="HS256")
            }
            payload = {"account_id": account_id, "query": question, "datasets": datasets}
            result = client.post("/v1/knowledge/search", json=payload, headers=headers)
            assert result.status_code == 200, result.status_code
            body = result.json()
            print(
                {
                    "observed_status": body["status"],
                    "matches": [(p["kind"], round(p["score"], 3)) for p in body["passages"]],
                },
                flush=True,
            )
            assert body["status"] == "ok", body["status"]
            assert {passage["kind"] for passage in body["passages"]} == {
                "faq",
                "document",
                "catalog",
            }
            assert all(len(passage["content"]) <= 8000 for passage in body["passages"])
            assert sum(len(passage["content"]) for passage in body["passages"]) <= 24000
            assert all(passage["content"] != document_text for passage in body["passages"])
            faq = next(passage for passage in body["passages"] if passage["kind"] == "faq")
            assert answer in faq["content"] and faq["title"].startswith("What are the Cobalt")
            print(
                {
                    "signed_mixed_search": "pass",
                    "kinds": [p["kind"] for p in body["passages"]],
                    "scores": [round(p["score"], 3) for p in body["passages"]],
                    "bounded_passages": True,
                },
                flush=True,
            )
            unrelated = client.post(
                "/v1/knowledge/search",
                json={**payload, "query": "Who won the football World Cup in 1966?"},
                headers=headers,
            )
            assert unrelated.status_code == 200 and unrelated.json()["status"] == "no_match"
            long_query = client.post(
                "/v1/knowledge/search", json={**payload, "query": question * 8}, headers=headers
            )
            assert long_query.status_code == 200 and len(long_query.json()["query"]) <= 250
            for query in (
                "How do I file income taxes in Italy?",
                "Explain how nuclear fusion powers the sun.",
            ):
                negative = client.post(
                    "/v1/knowledge/search", json={**payload, "query": query}, headers=headers
                )
                assert negative.status_code == 200 and negative.json()["status"] == "no_match", (
                    query
                )
            foreign = client.post(
                "/v1/knowledge/search",
                json={**payload, "account_id": account_id + 1},
                headers=headers,
            )
            assert foreign.status_code == 403
            assert client.post("/v1/knowledge/search", json=payload).status_code == 401
            expired = {**claims, "iat": now - 120, "nbf": now - 120, "exp": now - 60}
            expired_header = {
                "Authorization": "Bearer "
                + jwt.encode(expired, config.signing_key.get_secret_value(), algorithm="HS256")
            }
            assert (
                client.post(
                    "/v1/knowledge/search", json=payload, headers=expired_header
                ).status_code
                == 401
            )
            write = {**claims, "action": "knowledge:write"}
            write_header = {
                "Authorization": "Bearer "
                + jwt.encode(write, config.signing_key.get_secret_value(), algorithm="HS256")
            }
            assert (
                client.post("/v1/knowledge/search", json=payload, headers=write_header).status_code
                == 403
            )
            print(
                {
                    "off_topic_no_match": True,
                    "foreign_account_denied": True,
                    "missing_expired_and_write_credentials_denied": True,
                },
                flush=True,
            )
    finally:
        client.close()
        with Dify(connection) as remote:
            for dataset in datasets:
                remote.request("DELETE", f"datasets/{dataset['dataset_id']}")
        with engine().begin() as conn:
            conn.execute(delete(s.accounts).where(s.accounts.c.id == tenant_id))


if __name__ == "__main__":
    main()
