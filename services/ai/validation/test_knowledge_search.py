import json
import threading
import unittest
from unittest.mock import patch
from uuid import uuid4

import httpx
from pydantic import SecretStr, ValidationError

from cwai.config import DifyConnection
from cwai.contracts import KnowledgeSearch, SearchDataset
from cwai.dify import Dify, ProjectionError
from cwai.knowledge_search import normalize_query, search


class KnowledgeSearchTest(unittest.TestCase):
    def setUp(self):
        self.config = DifyConnection(
            url="https://dify.test/v1",
            api_key=SecretStr("test-only"),
            embedding_provider="fixture",
            embedding_model="fixture",
            reranking_provider="fixture",
            reranking_model="rerank-2.5",
        )
        self.datasets = [
            SearchDataset(dataset_id=str(uuid4()), kind=kind)
            for kind in ("faq", "document", "catalog")
        ]
        self.payload = KnowledgeSearch(
            account_id=1, query="Opening hours and products?", datasets=self.datasets
        )
        self.records = {
            dataset.dataset_id: [
                {
                    "score": score,
                    "segment": {
                        "document_id": str(uuid4()),
                        "enabled": True,
                        "status": "completed",
                        "content": content,
                        "answer": answer,
                        "document": {"name": "source.pdf", "doc_metadata": metadata},
                    },
                }
            ]
            for dataset, score, content, answer, metadata in zip(
                self.datasets,
                [0.9, 0.8, 0.95],
                [
                    "When are you open?",
                    "Delivery takes two business days.",
                    "Product: Cobalt compass\nProduct handle: cobalt-compass\n"
                    "A navigation product.",
                ],
                ["We are open 24/7.", None, None],
                [{}, {"source_url": "https://example.test/delivery"}, {}],
                strict=True,
            )
        }

    def test_parallel_search_combines_typed_native_faq_document_and_catalog_passages(self):
        barrier = threading.Barrier(3, timeout=3)

        def retrieve(_remote, dataset_id, query, limit):
            barrier.wait()
            self.assertEqual(query, self.payload.query)
            self.assertEqual(limit, 6)
            return self.records[dataset_id]

        with patch.object(Dify, "search", retrieve):
            result = search(self.config, self.payload, 0.3)
        self.assertEqual(result.status, "ok")
        self.assertEqual([p.kind for p in result.passages], ["catalog", "faq", "document"])
        self.assertEqual(result.passages[0].handle, "cobalt-compass")
        self.assertEqual(result.passages[1].title, "When are you open?")
        self.assertEqual(
            result.passages[1].content, "Question: When are you open?\nAnswer: We are open 24/7."
        )
        self.assertEqual(result.passages[2].url, "https://example.test/delivery")
        self.assertEqual([p.id for p in result.passages], [1, 2, 3])

    def test_below_threshold_and_disabled_results_are_no_match(self):
        for records in self.records.values():
            records[0]["score"] = 0.299
        self.records[self.datasets[0].dataset_id][0]["score"] = 0.99
        self.records[self.datasets[0].dataset_id][0]["segment"]["enabled"] = False
        with patch.object(Dify, "search", side_effect=lambda dataset, *_: self.records[dataset]):
            result = search(self.config, self.payload, 0.3)
        self.assertEqual(result.status, "no_match")
        self.assertEqual(result.passages, [])

    def test_deduplication_keeps_the_highest_score_without_dropping_distinct_passages(self):
        records = self.records[self.datasets[1].dataset_id]
        records.append({**records[0], "score": 0.7})
        records.append(
            {
                **records[0],
                "score": 0.6,
                "segment": {**records[0]["segment"], "content": "Delivery takes two"},
            }
        )
        with patch.object(Dify, "search", side_effect=lambda dataset, *_: self.records[dataset]):
            result = search(self.config, self.payload, 0.3)
        self.assertEqual(len(result.passages), 3)
        self.assertEqual(result.passages[-1].score, 0.8)

    def test_passage_and_total_budgets_never_return_whole_large_chunks(self):
        records = self.records[self.datasets[1].dataset_id]
        records[:] = [
            {
                **records[0],
                "score": 0.9 - n * 0.01,
                "segment": {**records[0]["segment"], "content": str(n) + " passage " * 2000},
            }
            for n in range(8)
        ]
        payload = self.payload.model_copy(update={"datasets": [self.datasets[1]]})
        with patch.object(Dify, "search", return_value=records):
            result = search(self.config, payload, 0.3)
        self.assertTrue(result.passages)
        self.assertLessEqual(len(result.passages), 5)
        self.assertLessEqual(sum(len(p.content) for p in result.passages), 24000)
        self.assertTrue(all(len(p.content) <= 8000 for p in result.passages))
        self.assertTrue(all(p.content.endswith(" ...") for p in result.passages))

    def test_remote_failure_is_not_disguised_as_no_match(self):
        with patch.object(Dify, "search", side_effect=ProjectionError("dify_http_503")):
            with self.assertRaises(ProjectionError):
                search(self.config, self.payload, 0.3)

    def test_normalization_strips_email_greetings_prefixes_keywords_and_caps_query(self):
        self.assertEqual(
            normalize_query("Hello\nWhen are you open?\nKind regards", "hours"),
            "hours When are you open?",
        )
        self.assertLessEqual(len(normalize_query("long question " * 100, "model")), 250)
        with self.assertRaises(ValidationError):
            KnowledgeSearch(account_id=1, query=" ", datasets=self.datasets)
        with self.assertRaises(ValidationError):
            KnowledgeSearch(
                account_id=1, query="Question?", datasets=[self.datasets[0], self.datasets[0]]
            )

    def test_hybrid_search_uses_the_server_reranker_and_only_the_retrieve_endpoint(self):
        requests = []

        def reply(request):
            requests.append(request)
            return httpx.Response(200, json={"records": []})

        with Dify(self.config) as remote:
            remote.client.close()
            remote.client = httpx.Client(
                base_url=self.config.url + "/", transport=httpx.MockTransport(reply)
            )
            remote.search(self.datasets[0].dataset_id, "hours", 6)
        body = json.loads(requests[0].content)
        self.assertEqual(body["retrieval_model"]["search_method"], "hybrid_search")
        self.assertTrue(body["retrieval_model"]["reranking_enable"])
        self.assertEqual(
            body["retrieval_model"]["reranking_model"]["reranking_model_name"], "rerank-2.5"
        )
        self.assertTrue(requests[0].url.path.endswith("/retrieve"))


if __name__ == "__main__":
    unittest.main()
