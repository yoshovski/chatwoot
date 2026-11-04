# Reply evals

`captain:eval` runs invented conversations through the real reply pipeline (router, direct route or action agent,
composer) with the real models through LiteLLM and checks every reply with deterministic rules. Specs stub the LLM,
so they can't see what the model writes; this is the check that does.

A run writes nothing: each case builds its account, inbox, agent, contact and conversation inside one transaction that
is rolled back, jobs go to the ActiveJob test adapter, and knowledge searches are answered from the suite's fixture
documents instead of Dify. Only the LLM calls leave the process.

## When to run it

Before releasing a change to a prompt, the response schema, routing or the reply composer. Attach the Markdown report
to the PR or release (the PR template asks for it). Never in CI: it costs credits and needs the LiteLLM key.

## Run it on lab

Deploy the candidate image to lab first, then on lab:

```bash
./deploy.sh status   # the live colour
docker exec -it chatwoot-<live colour>-rails-1 bundle exec rails captain:eval SUITE=reply_basics REPEAT=3 CONFIRM=1
docker cp chatwoot-<live colour>-rails-1:/app/tmp/evals ./evals
```

## Run it locally

Needs Postgres, Redis and the Captain LLM settings (`CAPTAIN_OPEN_AI_API_KEY` and `CAPTAIN_OPEN_AI_ENDPOINT` in
installation config, pointing at LiteLLM). Models come from `CAPTAIN_INTENT_ROUTER_MODEL`,
`CAPTAIN_KNOWLEDGE_ANSWER_MODEL` and `CAPTAIN_ACTION_MODEL`, as in production.

```bash
bundle exec rails captain:eval SUITE=reply_basics ONLY=R01,R04 REPEAT=1
```

| Variable | Default | |
|---|---|---|
| `SUITE` | `reply_basics` | a name in `suites/` or a path to a YAML file |
| `REPEAT` | `3` | runs per case; a case passes only when every run passes |
| `ONLY` | all | comma-separated case ids |
| `OUT` | `tmp/evals` | where the `.md` report and `.json` run record go |
| `JUDGE` | off | `1` lets a cheap model grade the `judge` rubrics; without it they are skipped |
| `CONFIRM` | off | required when a run needs more than 100 LLM calls |
| `IMAGE_TAG` | the commit | the revision the report names; without it the image's commit (`/app/.git_sha`) |

Exit code 0 when every case passes, 1 when one fails, 2 on a setup error. Routing is forced on for the run
(`CAPTAIN_INTENT_ROUTING_MODE=on`, no account filter) unless a case sets `routing: off`.

## Cost

About 2–3 LLM calls per case and repeat (router, answer, sometimes a retry or a tool turn); the task prints an estimate
first and each case's actual count. `reply_basics` with `REPEAT=3` is up to about 126 calls, so it needs `CONFIRM=1`.
Most calls go to the router and direct-answer models (Gemini Flash-Lite class); only action-agent cases (lead capture,
handoff, scenarios, unknown routes) use the larger action model. Check LiteLLM spend for the exact cost of a run.

## Adding a case

Cases live in `suites/*.yml`. Use invented businesses only (no client names, URLs or transcripts).

```yaml
- id: R15
  title: Short description shown in the report
  settings: { limits: [{ cannot: issue refunds, offer: handoff }] }   # merchant content only; merged over `defaults`
  history: [{ role: user, content: ... }, { role: assistant, content: ... }]   # earlier turns, optional
  channel: email            # default web widget
  campaign: Opener text     # the conversation started with this campaign message
  scenarios: [{ title:, description:, instruction: }]
  locale: de
  message: The customer's message
  expect:
    route: faq_kb           # smalltalk, faq_kb, action_agent or business_overview
    checks: [welcome_once, { bubbles: { min: 1, max: 2 } }]
```

Checks (`checks.rb`): `welcome_once`, `starts_with_greeting`, `no_repeated_sentences`, `no_empty_bubbles`, `bubbles`,
`question_bubble`, `no_click_paths`, `links_from_knowledge`, `contains_video`, `mentions_all` (a list of terms the reply
names), `language`, `handoff`, `route`, `max_chars`, `judge` (a rubric, graded only with `JUDGE=1`) and `any_of` (a list
of checks, one of which must pass). The suite's SHA-256 in the report names exactly which
cases ran.
