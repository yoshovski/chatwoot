# Captain lab baseline

CWAI-19 establishes an isolated baseline before Captain's knowledge, Shopify tools and reply
controls change. Runtime behavior stays as-is for this task. The task's private Huly issue and
plan hold client settings, source snapshots, evaluation questions and observed replies.

Use a separate lab account and website inbox with Captain v2 and no AgentBot. Verify the lab
model gateway and the temporary embedding alias through Captain's actual embedding service.
Import the source FAQs without rewriting them, then load the main policy pages through the
existing Documents flow. Record source conflicts explicitly. Verify a playground answer and
an outgoing Captain reply through the website inbox.

Record any owner-approved source deferrals in the private task evidence. Keep the omitted
sources visible in the evaluation expectations, and do not count unsupported factual
expectations as passed. A source deferral does not authorize changing runtime behavior.
If the owner defers further measurements, preserve the recorded runs and list unexecuted,
blocked and unscored checks explicitly. Do not describe a partial baseline as an acceptance pass.

Create a client workspace and knowledge key in lab Dify. Use a separate lab Shopify Agent Tools
tenant and the approved store/app. Credentials stay on the server. Deployments require a
separate approval; creating baseline records does not authorize a deployment or production write.

## Private evaluation records

Freeze approximately 45 cases covering knowledge, products, orders, sales, missing facts,
languages, attachments and conversation interactions. Include the button click and form
submission as replay steps, along with starters, campaigns, handoff and resolution events.
Each case records expected answers, sources, buttons, cards, labels and handoff behavior.

Store a UTF-8 JSON evaluation file outside the repository:

```json
{
  "version": 1,
  "cases": [{
    "id": "E01",
    "steps": ["Ask the synthetic example question"],
    "expected": {
      "answer": "Example answer",
      "source": "Synthetic source snapshot",
      "buttons": [], "product_handles": [], "labels": [], "handoff": false
    }
  }]
}
```

Compute `fixture_sha256` with `fixture_hash` from
`services/ai/validation/captain_lab_bench.py`. The hash includes replay steps and expected
results. Changing an oracle requires a new snapshot and new comparable runs.

Replay the same file on Captain as-is and on the reference agent copied into lab Dify. Each
baseline file identifies `engine` (`captain` or `reference`), the exact runtime `revision`,
the `fixture_sha256` and a `results` array. A completed result has this shape:

```json
{
  "id": "E01", "status": "completed", "verdict": "pass",
  "actual": {
    "messages": ["Example answer"], "sources": [], "buttons": [],
    "product_handles": [], "labels": [], "events": [], "handoff": false
  }
}
```

Record every output dimension, including empty lists when nothing was emitted. `events` holds
observed interaction/state changes. Save raw replies and trace/conversation references in
private evidence alongside these records. Keep factual expectations separate from observations.
Record any approved model differences in the private fixture and run provenance so retrieval
and answer differences can be interpreted against the actual lab configuration.
`verdict` is `pass`, `fail` or `unscored`; a measured baseline failure is still a completed replay.
Use `status: "blocked"` with a nonempty `reason` when a prerequisite prevented execution.

Validate the private files:

```sh
python3 services/ai/validation/captain_lab_bench.py \
  /private/evaluation.json /private/captain.json /private/reference.json
```

The checker prints counts only. Exit 0 means both runs cover the frozen set with no blocked
cases; it does not mean behavior passed. Exit 1 reports missing/blocked execution, and exit 2
reports invalid/unreadable records. Duplicate/unknown case IDs, different snapshots, missing
runtime revisions and incomplete observation shapes are rejected. It does not execute cases
or replace manual assessment of answers and UI behavior.

Run its tests and lint from `services/ai`:

```sh
python3 -m unittest discover -s validation -p test_captain_lab_bench.py
ruff check validation/captain_lab_bench.py validation/test_captain_lab_bench.py
ruff format --check validation/captain_lab_bench.py validation/test_captain_lab_bench.py
```

Keep client content, store identities, prompts, rules, credentials and customer data outside
the public fork. Save the collected baseline evidence and any deferrals in Huly before opening
the task PR, then move the issue to Review in progress. Merge and release only with owner authorization.
