import math
import re
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select

from cwai import schema as s
from cwai.auth import Scope, read_scope
from cwai.config import settings
from cwai.contracts import KnowledgePassage, KnowledgeSearch, KnowledgeSearchResult
from cwai.db import engine
from cwai.dify import Dify, ProjectionError

router = APIRouter(prefix="/v1/knowledge")
MAX_PASSAGES = 5
PER_PASSAGE_CHARS = 8000
TOTAL_CHARS = 24000
# The installed Dify retrieve API limits queries to 250 characters (below the workflow's 420 cap).
MAX_QUERY_CHARS = 250
GREETING = re.compile(
    r"^(hi|hello|hey|dear|good (morning|afternoon|evening)|thanks|thank you|"
    r"many thanks|regards|best regards|kind regards|sincerely|cheers|"
    r"i look forward|looking forward)\b",
    re.I,
)
EXT = re.compile(r"\.(md|txt|json|html?|pdf|docx?|csv)$", re.I)
P_HANDLE = re.compile(r"^\s*Product handle:\s*([a-z0-9][a-z0-9_-]*)\s*$", re.I | re.M)
P_NAME = re.compile(r"^\s*Product:\s*(.+)$", re.M)
FAQ_Q = re.compile(r"^\s*question:\s*(.+)$", re.I | re.M)


def normalize_query(question, keywords=""):
    query = question.strip()
    kept = [
        line.strip()
        for line in query.splitlines()
        if line.strip() and not GREETING.match(line.strip())
    ]
    if kept:
        query = " ".join(kept)
    query = re.sub(r"\s+", " ", query).strip()
    merged = (keywords.strip() + " " + query).strip()
    return merged[:MAX_QUERY_CHARS].rsplit(" ", 1)[0] if len(merged) > MAX_QUERY_CHARS else merged


def clipped(text, limit):
    if len(text) <= limit:
        return text
    return text[: limit - 4].rsplit(" ", 1)[0] + " ..."


def passage(dataset, record):
    segment = record["segment"]
    score = record["score"]
    if (
        score is None
        or not math.isfinite(score)
        or not segment["enabled"]
        or segment["status"] != "completed"
    ):
        return None
    content = segment["content"].strip()
    if not content:
        return None
    answer = segment.get("answer")
    document = segment["document"]
    metadata = document.get("doc_metadata") or {}
    handle = None
    if dataset.kind == "catalog":
        match = P_HANDLE.search(content)
        handle = metadata.get("handle") or (match.group(1).lower() if match else None)
    name_match = P_NAME.search(content)
    question_match = FAQ_Q.search(content)
    title = EXT.sub("", document["name"]).strip() or "Untitled"
    if question_match:
        title = question_match.group(1).strip()
    if answer is not None:
        title = content
    if dataset.kind == "catalog" and name_match:
        title = name_match.group(1).strip()
    if answer is not None:
        content = f"Question: {content}\nAnswer: {answer}"
    url = metadata.get("source_url") or metadata.get("url") or metadata.get("link")
    if url and (urlsplit(url).scheme not in {"http", "https"} or not urlsplit(url).netloc):
        url = None
    return KnowledgePassage(
        id=1,
        kind=dataset.kind,
        dataset_id=dataset.dataset_id,
        document_id=segment["document_id"],
        title=clipped(title, 90),
        content=clipped(content, PER_PASSAGE_CHARS),
        url=url,
        handle=handle,
        score=float(score),
    ), content


def search(config, payload, threshold):
    if not config.reranking_provider or not config.reranking_model:
        raise ProjectionError("dify_reranker_not_configured")
    query = normalize_query(payload.query, payload.keywords)
    with (
        Dify(config) as remote,
        ThreadPoolExecutor(max_workers=len(payload.datasets)) as pool,
    ):
        futures = [
            (dataset, pool.submit(remote.search, dataset.dataset_id, query, dataset.limit))
            for dataset in payload.datasets
        ]
        candidates = [
            candidate
            for dataset, future in futures
            for record in future.result()
            if (candidate := passage(dataset, record)) is not None
            and candidate[0].score >= threshold
        ]
    candidates.sort(key=lambda candidate: candidate[0].score, reverse=True)
    passages = []
    accepted = []
    total = 0
    for item, original in candidates:
        if any(original in content or content in original for content in accepted):
            continue
        if total + len(item.content) > TOTAL_CHARS:
            continue
        accepted.append(original)
        total += len(item.content)
        passages.append(item.model_copy(update={"id": len(passages) + 1}))
        if len(passages) == MAX_PASSAGES:
            break
    return KnowledgeSearchResult(
        status="ok" if passages else "no_match", query=query, passages=passages
    )


@router.post("/search", response_model=KnowledgeSearchResult)
def knowledge_search(payload: KnowledgeSearch, auth: Scope = Depends(read_scope)):
    with engine().connect() as conn:
        account = (
            conn.execute(select(s.accounts).where(s.accounts.c.id == auth.tenant_id))
            .mappings()
            .one()
        )
    if account["account_id"] != payload.account_id:
        raise HTTPException(403, "Account does not match service credential")
    config = settings()
    return search(
        config.dify_connections[account["credential_ref"]],
        payload,
        config.knowledge_search_score_threshold,
    )
