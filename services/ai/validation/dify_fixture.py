"""Isolated Dify protocol fixture for the lab/CI fault-injection run; never deploy."""

from uuid import uuid4

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse

app = FastAPI()
workspaces = {}
fail_after_create = 0
fail_requests = 0


@app.get("/health")
def health():
    return {"status": "ok"}


def workspace(authorization):
    if not authorization:
        raise HTTPException(401)
    return workspaces.setdefault(authorization, {})


@app.post("/control")
async def control(request: Request):
    global fail_after_create, fail_requests
    payload = await request.json()
    fail_after_create = payload.get("fail_after_create", 0)
    fail_requests = payload.get("fail_requests", 0)
    return {"ok": True}


@app.middleware("http")
async def fail(request, call_next):
    global fail_requests
    if request.url.path.startswith("/v1") and fail_requests:
        fail_requests -= 1
        return JSONResponse({"detail": "lab fault"}, status_code=503)
    return await call_next(request)


@app.get("/v1/datasets")
def datasets(authorization: str = Header()):
    return {"data": list(workspace(authorization).values()), "has_more": False}


@app.post("/v1/datasets")
async def dataset_create(request: Request, authorization: str = Header()):
    data = await request.json()
    data.update(id=str(uuid4()), documents={})
    workspace(authorization)[data["id"]] = data
    return {"id": data["id"]}


def dataset(authorization, dataset_id):
    value = workspace(authorization).get(dataset_id)
    if value is None:
        raise HTTPException(404)
    return value


@app.get("/v1/datasets/{dataset_id}")
def dataset_get(dataset_id: str, authorization: str = Header()):
    return dataset(authorization, dataset_id)


@app.delete("/v1/datasets/{dataset_id}")
def dataset_delete(dataset_id: str, authorization: str = Header()):
    dataset(authorization, dataset_id)
    del workspace(authorization)[dataset_id]
    return {"ok": True}


@app.get("/v1/datasets/{dataset_id}/documents")
def documents(dataset_id: str, keyword: str = "", authorization: str = Header()):
    docs = dataset(authorization, dataset_id)["documents"].values()
    return {"data": [d for d in docs if keyword in d["name"]], "has_more": False}


@app.post("/v1/datasets/{dataset_id}/document/create-by-text")
async def create_document(dataset_id: str, request: Request, authorization: str = Header()):
    global fail_after_create
    body = await request.json()
    doc = {
        "id": str(uuid4()),
        "name": body["name"],
        "text": body["text"],
        "indexing_status": "completed",
        "segment_id": str(uuid4()),
    }
    dataset(authorization, dataset_id)["documents"][doc["id"]] = doc
    if fail_after_create:
        fail_after_create -= 1
        return JSONResponse({"detail": "accepted then lost acknowledgement"}, status_code=503)
    return {"document": doc, "batch": doc["id"]}


@app.get("/v1/datasets/{dataset_id}/documents/{batch_id}/indexing-status")
def status(dataset_id: str, batch_id: str, authorization: str = Header()):
    doc = dataset(authorization, dataset_id)["documents"].get(batch_id)
    return {"data": [doc] if doc else []}


@app.get("/v1/datasets/{dataset_id}/documents/{document_id}/segments")
def segments(dataset_id: str, document_id: str, authorization: str = Header()):
    doc = dataset(authorization, dataset_id)["documents"].get(document_id)
    if not doc:
        raise HTTPException(404)
    return {
        "data": [{"id": doc["segment_id"], "status": "completed", "content": doc["text"]}],
        "has_more": False,
    }


@app.delete("/v1/datasets/{dataset_id}/documents/{document_id}")
def delete_document(dataset_id: str, document_id: str, authorization: str = Header()):
    docs = dataset(authorization, dataset_id)["documents"]
    if document_id not in docs:
        raise HTTPException(404)
    del docs[document_id]
    return {"ok": True}


@app.post("/v1/datasets/{dataset_id}/retrieve")
def retrieve(dataset_id: str, authorization: str = Header()):
    return {
        "records": [
            {
                "segment": {
                    "id": d["segment_id"],
                    "document_id": d["id"],
                    "content": "UNTRUSTED REMOTE CONTENT",
                },
                "score": 0.9,
            }
            for d in dataset(authorization, dataset_id)["documents"].values()
        ]
    }
