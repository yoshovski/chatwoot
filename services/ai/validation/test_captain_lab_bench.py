import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from captain_lab_bench import InvalidBaseline, fixture_hash, summarize_run


class CaptainLabBenchTest(unittest.TestCase):
    def setUp(self):
        self.fixture = {
            "version": 1,
            "cases": [
                {
                    "id": "E01",
                    "steps": ["Ask a synthetic FAQ"],
                    "expected": {"source": "synthetic FAQ snapshot", "answer": "Example answer"},
                },
                {
                    "id": "E02",
                    "steps": ["Request a synthetic product"],
                    "expected": {"source": "synthetic catalog snapshot", "cards": 1},
                },
            ],
        }
        self.run = {
            "engine": "captain",
            "revision": "synthetic-test-revision",
            "fixture_sha256": fixture_hash(self.fixture),
            "results": [
                {
                    "id": "E01",
                    "status": "completed",
                    "verdict": "pass",
                    "actual": {
                        "messages": ["Example answer"],
                        "sources": [],
                        "buttons": [],
                        "product_handles": [],
                        "labels": [],
                        "events": [],
                        "handoff": False,
                    },
                }
            ],
        }

    def test_changed_oracle_invalidates_prior_results(self):
        changed = copy.deepcopy(self.fixture)
        changed["cases"][0]["expected"]["answer"] = "A different answer"
        with self.assertRaises(InvalidBaseline):
            summarize_run(changed, self.run, "captain")

    def test_reordered_object_keys_do_not_change_snapshot_identity(self):
        reordered = {"cases": self.fixture["cases"], "version": 1}
        self.assertEqual(fixture_hash(self.fixture), fixture_hash(reordered))

    def test_missing_and_blocked_cases_are_not_completed(self):
        summary = summarize_run(self.fixture, self.run, "captain")
        self.assertEqual(summary["missing"], 1)
        self.run["results"].append({"id": "E02", "status": "blocked", "reason": "No lab store"})
        summary = summarize_run(self.fixture, self.run, "captain")
        self.assertEqual(summary["missing"], 0)
        self.assertEqual(summary["completed"], 1)
        self.assertEqual(summary["blocked"], 1)

    def test_execution_failure_is_recorded_as_an_observed_baseline(self):
        self.run["results"][0]["verdict"] = "fail"
        summary = summarize_run(self.fixture, self.run, "captain")
        self.assertEqual(summary["completed"], 1)
        self.assertEqual(summary["fail"], 1)

    def test_rejects_duplicate_and_unknown_results(self):
        for identifier in ("E01", "unknown"):
            with self.subTest(identifier=identifier):
                changed = copy.deepcopy(self.run)
                result = copy.deepcopy(changed["results"][0])
                result["id"] = identifier
                changed["results"].append(result)
                with self.assertRaises(InvalidBaseline):
                    summarize_run(self.fixture, changed, "captain")

    def test_cannot_replace_reference_results_with_captain_results(self):
        with self.assertRaises(InvalidBaseline):
            summarize_run(self.fixture, self.run, "reference")

    def test_completed_record_requires_all_observation_dimensions(self):
        for field in self.run["results"][0]["actual"]:
            with self.subTest(field=field):
                changed = copy.deepcopy(self.run)
                del changed["results"][0]["actual"][field]
                with self.assertRaises(InvalidBaseline):
                    summarize_run(self.fixture, changed, "captain")

    def test_cli_reports_only_counts_and_rejects_incomplete_execution(self):
        reference = copy.deepcopy(self.run)
        reference["engine"] = "reference"
        with TemporaryDirectory() as directory:
            paths = [
                Path(directory) / name for name in ("fixture.json", "captain.json", "ref.json")
            ]
            for path, data in zip(paths, (self.fixture, self.run, reference), strict=True):
                path.write_text(json.dumps(data), encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).with_name("captain_lab_bench.py")),
                    *map(str, paths),
                ],
                check=False,
                text=True,
                capture_output=True,
            )
        self.assertEqual(result.returncode, 1)
        self.assertFalse(json.loads(result.stdout)["execution_complete"])
        self.assertNotIn("Example answer", result.stdout)
        self.assertNotIn("synthetic FAQ", result.stdout)


if __name__ == "__main__":
    unittest.main()
