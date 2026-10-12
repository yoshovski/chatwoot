# ADR: Shared conversation context and model roles

Status: Implemented locally in `feat/intent-routing`; not deployed.
Date: 2026-10-12
Decider: Stefan

## Context

The intent-routing branch provides canned greetings, combined classification/query preparation, direct knowledge answers, shared citation handling, typing and staged rollout. The original six-message/6,000-character fast-path history limit could lose important earlier details; it has now been replaced by shared conversation memory. The existing full agent still receives full history. The user already has Gemini 3.5 Flash-Lite and GPT-6 Luna configured through LiteLLM; exact proxy model aliases must be verified before configuration.

## Decision

Keep every model request through the existing LiteLLM gateway. Replace fixed history truncation with one shared conversation-context service containing a bounded verbatim tail, rolling summary, structured facts and authoritative workflow state. Keep the complete original Chatwoot transcript. Conversation memory remains account/conversation scoped in Chatwoot, separate from Dify business knowledge.

Initial model roles:

| Role | Initial model | Optional alternative |
| --- | --- | --- |
| Classification and up to two retrieval queries | Existing Gemini 3.5 Flash-Lite alias | Direct Mistral Ministral 3 8B after evaluation |
| Direct RAG and non-canned smalltalk | Existing Gemini 3.5 Flash-Lite alias | Compare existing GPT-6 Luna on answer grounding |
| Summary and fact extraction | Existing Gemini 3.5 Flash-Lite alias, background jobs | Existing GPT-6 Luna if summary fidelity is better |
| Action workflows and tools | Verify the existing GPT-6 Luna alias supports the required tools/schema; preserve the current model until validated | Existing configured action model |

Use independent logical aliases/settings for `intent-router`, `knowledge-answer`, `conversation-summary` and the existing action route. Adding a provider is not required to implement memory or deploy the initial router.

## Context budgets and compaction

Starting values, to be tuned on real conversations:

- Recent verbatim messages: about 3,000 tokens, ending on complete conversational turns.
- Rolling summary: up to 700 tokens.
- Extracted facts: about 300–500 tokens; required workflow identifiers stay exact and take priority.
- Schedule compaction when the unsummarized tail exceeds roughly 6,000 tokens.
- At an approximately 8,000-token unsummarized tail, catch up before applying a destructive cutoff. On failure, retain required context or use the existing agent path when it fits; do not silently forget uncovered messages.
- Reserve separate budgets for instructions, retrieval passages, tool schemas/results and output. Count tokens locally using a tokenizer where supported, otherwise a conservative estimate checked against provider usage.

A background Sidekiq job reads the previous summary plus newly eligible messages and produces one structured result containing both the updated summary and extracted facts. It leaves approximately 3,000 tokens of recent messages untouched. The job runs after message/response commits and does not add a normal per-message summarization request.

A reply uses the last completed summary plus ALL messages after its covered-message cursor. While compaction is pending this may temporarily exceed the target tail size, up to the hard-budget policy. Current messages and corrections outrank older memory. The router may receive a smaller view, but must retain facts and recent exchanges needed to resolve references; the answer and agent consume the same snapshot/version.

Persist an account-scoped conversation memory row with summary, structured facts, covered-message ID, resolution boundary, revision and summarizer/prompt version. Use a unique conversation identity, foreign keys and atomic revision/cursor checks. Generate outside database locks; an older job cannot overwrite a newer summary. Edits/deletions affecting covered messages invalidate the relevant summary. Rebuild disputed information from original source messages instead of repeatedly paraphrasing an incorrect summary.

Facts include product identifiers, customer requirements and exclusions, quantities, chosen/rejected options and unresolved questions, each with source message references. Customer claims remain distinct from verified facts. Action completion, ownership and handoff status come from authoritative application/tool records, never summary inference. Prices, inventory and order status still require live tools.

Resolution starts a new active workflow boundary. It must not silently resume an old quote or transfer. Older factual context can be recovered if the customer explicitly refers to it. Sensitive values are not placed in source files, documentation, logs or prompts unless necessary for the authorized runtime operation.

## Options considered

| Option | Complexity | Cost/latency | Continuity |
| --- | --- | --- | --- |
| Keep last N messages | Low | Low | Loses older constraints and references |
| Always send full transcript | Low initially | Grows indefinitely | Preserves text, but increases distraction and token cost |
| Summarize on every message | Medium | Extra call on every reply | Redundant work and repeated compression |
| Shared bounded context with background compaction | Medium | Bounded regular calls; occasional background work | Recommended, with original-source recovery |

## Additional provider shortlist

Published standard prices in USD per million input/output tokens, checked 2026-10-12:

- Direct Mistral Ministral 3 8B (`ministral-8b-2512`): $0.15 / $0.15. Structured outputs supported. Recommended first external challenger for combined intent and query preparation.
- Direct Mistral Ministral 3 3B (`ministral-3b-2512`): $0.10 / $0.10. Cheaper candidate; evaluate query fidelity and multilingual ambiguity before preferring it over 8B.
- Together Qwen3.5 9B (`Qwen/Qwen3.5-9B`): $0.17 / $0.25. Structured outputs supported; benchmark with thinking disabled if supported by the selected endpoint.
- Cerebras self-serve Developer is explicitly for experimentation, not production; do not use that tier as the production default. Enterprise/partner options can be assessed separately.
- Groq is excluded from the initial plan because the user cannot obtain the needed developer access.

None of the reviewed public pages establishes sub-300-ms end-to-end completion for this application's prompt. Published generation throughput is not time-to-completed-JSON. Benchmark from the deployment region through LiteLLM and include retries, queues and reasoning tokens in measured cost.

References:

- https://docs.mistral.ai/inference/pricing
- https://docs.mistral.ai/models/ministral-3-8b-25-12
- https://docs.mistral.ai/models/ministral-3-3b-25-12
- https://docs.mistral.ai/getting-started/quickstarts/developer/first-api-request
- https://docs.litellm.ai/docs/providers/mistral
- https://docs.together.ai/docs/serverless/models
- https://www.cerebras.ai/pricing
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://reference.langchain.com/python/langchain/agents/middleware/summarization/SummarizationMiddleware
- https://arxiv.org/abs/2410.10813

## Implementation sequence and acceptance

1. Verify actual existing LiteLLM aliases and required JSON/tool capabilities without changing the action model.
2. Add persistent conversation memory schema, source references and concurrency-safe compaction jobs.
3. Implement shared context construction and replace the fast-path fixed history limit; retain the current full-agent path during rollout.
4. Add separate summary model setting. Wire automatic compaction, pending-summary handling and resolution/edit invalidation.
5. Evaluate Gemini and Luna on long conversations; optionally benchmark direct Mistral 8B/3B for routing.
6. Run shadow mode for selected accounts, then enable direct routing. Enable bounded action-agent context separately after workflow validation.

Acceptance covers later corrections, product references after many turns, rejected products, negations, quote quantities, unresolved questions, resolution/reopen boundaries, source recovery, stale live data, duplicate/out-of-order compaction jobs, pending/failed summaries, message edits, tenant isolation, tool-call/result pairing and retention/deletion behavior. Measure unsafe action-to-FAQ routing, query fidelity, summary recall, grounded answers, p50/p95 completion latency and cost per routed message. Provider failure/invalid JSON goes directly to the existing agent; avoid serial retries across classifiers.

## Implementation status

Persistent summary/fact storage, source fingerprints, automatic background compaction, revision checks, edit/delete/resolution invalidation, shared router/direct-answer context, optional compacted action/scenario history, original-source lookup and independent summary alias settings are implemented locally. The new Rails migration was applied only to the local test database. Provider configuration and production deployment remain unchanged. Model-specific tokenizers are not introduced; conservative local estimates are used and should be calibrated against actual gateway usage.
