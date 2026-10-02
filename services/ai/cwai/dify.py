from urllib.parse import quote

import httpx

from cwai.config import DifyConnection


class ProjectionError(Exception):
    """Safe error code; never store remote response bodies or credentials."""


class Dify:
    def __init__(self, config: DifyConnection):
        self.config = config
        self.client = httpx.Client(
            base_url=config.url.rstrip("/") + "/",
            timeout=20,
            headers={"Authorization": f"Bearer {config.api_key.get_secret_value()}"},
        )

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.client.close()

    def request(self, method, path, **kwargs):
        try:
            result = self.client.request(method, path, **kwargs)
        except httpx.TransportError:
            raise ProjectionError("dify_transport") from None
        if result.status_code == 404:
            raise ProjectionError("dify_not_found")
        if not result.is_success:
            raise ProjectionError(f"dify_http_{result.status_code}")
        if result.status_code == 204 or not result.content:
            return None
        try:
            return result.json()
        except ValueError:
            raise ProjectionError("dify_invalid_json") from None

    def pages(self, path, **params):
        page = 1
        while True:
            result = self.request("GET", path, params={"page": page, "limit": 100, **params})
            yield from result["data"]
            if not result["has_more"]:
                break
            page += 1

    def dataset(self, projection):
        if projection["dataset_id"]:
            # A missing dataset is repaired from canonical records; other errors are retried.
            try:
                self.request("GET", f"datasets/{quote(projection['dataset_id'], safe='')}")
                return projection["dataset_id"]
            except ProjectionError as error:
                if str(error) != "dify_not_found":
                    raise
        name = "cwai-" + projection["id"].replace("-", "")
        matches = [d for d in self.pages("datasets") if d["name"] == name]
        if len(matches) > 1:
            raise ProjectionError("dify_duplicate_dataset")
        if matches:
            return matches[0]["id"]
        return self.request(
            "POST",
            "datasets",
            json={
                "name": name,
                "permission": "only_me",
                "indexing_technique": "high_quality",
                "embedding_model_provider": self.config.embedding_provider,
                "embedding_model": self.config.embedding_model,
            },
        )["id"]

    def document(self, dataset_id, binding, text):
        name = "cwai-" + binding["id"]
        path = f"datasets/{quote(dataset_id, safe='')}/documents"
        # Dify has no create idempotency key. Stable names recover an accepted POST
        # after a lost response or worker crash before the local commit.
        matches = [d for d in self.pages(path, keyword=name) if d["name"] == name]
        if len(matches) > 1:
            raise ProjectionError("dify_duplicate_document")
        if matches:
            return matches[0]["id"], None
        result = self.request(
            "POST",
            f"datasets/{dataset_id}/document/create-by-text",
            json={
                "name": name,
                "text": text,
                "doc_form": "text_model",
                "indexing_technique": "high_quality",
                "process_rule": {
                    "mode": "custom",
                    "rules": {
                        "pre_processing_rules": [
                            {"id": "remove_extra_spaces", "enabled": False},
                            {"id": "remove_urls_emails", "enabled": False},
                        ],
                        "segmentation": {"separator": "\n\n", "max_tokens": 1000},
                    },
                },
            },
        )
        return result["document"]["id"], result["batch"]

    def ready_segments(self, dataset_id, binding):
        if binding["batch_id"]:
            states = self.request(
                "GET", f"datasets/{dataset_id}/documents/{binding['batch_id']}/indexing-status"
            )["data"]
            states = [d for d in states if d["id"] == binding["document_id"]]
        else:
            states = [
                d
                for d in self.pages(f"datasets/{dataset_id}/documents")
                if d["id"] == binding["document_id"]
            ]
        if not states:
            raise ProjectionError("dify_document_missing")
        if states[0]["indexing_status"] in {"error", "paused"}:
            raise ProjectionError("dify_indexing_failed")
        if states[0]["indexing_status"] != "completed":
            return None
        segments = list(
            self.pages(f"datasets/{dataset_id}/documents/{binding['document_id']}/segments")
        )
        if not segments:
            raise ProjectionError("dify_empty_index")
        if any(segment["status"] != "completed" for segment in segments):
            return None
        return [segment["id"] for segment in segments]

    def delete_document(self, dataset_id, document_id):
        try:
            self.request("DELETE", f"datasets/{dataset_id}/documents/{document_id}")
        except ProjectionError as error:
            if str(error) != "dify_not_found":
                raise

    def retrieve(self, dataset_id, query, top_k):
        return self.request(
            "POST",
            f"datasets/{dataset_id}/retrieve",
            json={
                "query": query,
                "retrieval_model": {
                    "search_method": "semantic_search",
                    "reranking_enable": False,
                    "top_k": top_k,
                    "score_threshold_enabled": False,
                },
            },
        )["records"]
