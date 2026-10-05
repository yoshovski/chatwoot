"""Check private Captain/reference baseline records without printing their content."""

import argparse
import hashlib
import json
from pathlib import Path


class InvalidBaseline(ValueError):
    """The records cannot be compared against the frozen evaluation."""


def fixture_hash(fixture: dict) -> str:
    canonical = json.dumps(fixture, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode()).hexdigest()


def validate_fixture(fixture: dict) -> set[str]:
    if type(fixture.get("version")) is not int or fixture["version"] != 1:
        raise InvalidBaseline("Unsupported evaluation format")
    cases = fixture.get("cases")
    if not isinstance(cases, list) or not cases:
        raise InvalidBaseline("The evaluation must contain cases")
    identifiers = set()
    for case in cases:
        if not isinstance(case, dict):
            raise InvalidBaseline("Each case must be an object")
        identifier = case.get("id")
        if not isinstance(identifier, str) or not identifier or identifier in identifiers:
            raise InvalidBaseline("Case identifiers must be nonempty and unique")
        steps = case.get("steps")
        if (
            not isinstance(steps, list)
            or not steps
            or any(not isinstance(step, str) or not step for step in steps)
        ):
            raise InvalidBaseline("Each case needs its replay steps")
        expected = case.get("expected")
        if not isinstance(expected, dict) or not isinstance(expected.get("source"), str):
            raise InvalidBaseline("Each case needs an expected result and source oracle")
        if not expected["source"]:
            raise InvalidBaseline("The source oracle must be nonempty")
        identifiers.add(identifier)
    return identifiers


def summarize_run(fixture: dict, run: dict, engine: str) -> dict:
    identifiers = validate_fixture(fixture)
    if run.get("engine") != engine:
        raise InvalidBaseline("Unexpected baseline engine")
    if run.get("fixture_sha256") != fixture_hash(fixture):
        raise InvalidBaseline("Baseline used a different evaluation snapshot")
    if not isinstance(run.get("revision"), str) or not run["revision"]:
        raise InvalidBaseline("Baseline must identify its runtime revision")
    results = run.get("results")
    if not isinstance(results, list):
        raise InvalidBaseline("Baseline results must be a list")
    observed = set()
    counts = {"completed": 0, "blocked": 0, "pass": 0, "fail": 0, "unscored": 0}
    for result in results:
        if not isinstance(result, dict):
            raise InvalidBaseline("Each result must be an object")
        identifier = result.get("id")
        if not isinstance(identifier, str) or identifier not in identifiers:
            raise InvalidBaseline("Baseline contains an unknown case")
        if identifier in observed:
            raise InvalidBaseline("Baseline contains duplicate results")
        observed.add(identifier)
        status = result.get("status")
        if status not in ("completed", "blocked"):
            raise InvalidBaseline("Results must distinguish execution from blocked work")
        counts[status] += 1
        if status == "blocked":
            if not isinstance(result.get("reason"), str) or not result["reason"]:
                raise InvalidBaseline("Blocked results must explain the missing prerequisite")
            continue
        actual = result.get("actual")
        if not isinstance(actual, dict):
            raise InvalidBaseline("Completed results must include observations")
        for field in ("messages", "sources", "buttons", "product_handles", "labels", "events"):
            if not isinstance(actual.get(field), list):
                raise InvalidBaseline("Observations must include every output dimension")
        if not isinstance(actual.get("handoff"), bool):
            raise InvalidBaseline("Observed handoff must be a boolean")
        verdict = result.get("verdict")
        if verdict not in ("pass", "fail", "unscored"):
            raise InvalidBaseline("Completed results need a comparison verdict")
        counts[verdict] += 1
    return {
        "engine": engine,
        "cases": len(identifiers),
        "missing": len(identifiers - observed),
        **counts,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("captain", type=Path)
    parser.add_argument("reference", type=Path)
    args = parser.parse_args()
    try:
        fixture, captain, reference = (
            json.loads(path.read_text(encoding="utf-8"))
            for path in (args.fixture, args.captain, args.reference)
        )
        if not all(isinstance(value, dict) for value in (fixture, captain, reference)):
            raise InvalidBaseline("Evaluation and baseline files must be objects")
        runs = [
            summarize_run(fixture, captain, "captain"),
            summarize_run(fixture, reference, "reference"),
        ]
    except (OSError, json.JSONDecodeError, InvalidBaseline):
        print(json.dumps({"valid": False, "reason": "Invalid or unreadable baseline records"}))
        return 2
    complete = all(run["missing"] == 0 and run["blocked"] == 0 for run in runs)
    print(json.dumps({"valid": True, "execution_complete": complete, "runs": runs}))
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
