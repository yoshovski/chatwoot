# Captain V2 intent routing

Captain currently schedules a response job, builds full public message history and an assistant/scenario graph, then runs up to ten agent turns. Knowledge is retrieved when the FAQ tool is called; it is not fetched unconditionally. Replies are saved natively in Rails, not posted by an external webhook bot. Typing already starts in the job; this change also signals typing when an eligible message is scheduled.

## Pipeline

Eligible message → typing and scheduling → existing ownership/stale-message checks → router → shared response validation and delivery.

- Exact supported greetings/acknowledgments use local translations unless custom guardrails or response guidelines are configured.
- Other text gets one JSON classification/query-preparation call. It sees the shared rolling memory, every uncovered recent message, the latest message, scenario descriptions, short custom-capability summaries and assistant routing policies. The fixed six-message cutoff has been removed. It returns `intent` and up to two queries, each at most 250 characters. Temperature is zero and output budget is 200 tokens. No tools or passages are sent to this call.
- `smalltalk` generates once with no retrieval. Configured business context can answer simple identity questions.
- `faq_kb` searches FAQs, customer-visible documents, extra Dify datasets and the connected catalog. Two searches run concurrently, merge/deduplicate, and feed up to three passages with an 8,000-character content budget into one structured generation call with no tools. Existing citation indexing, source metadata and account isolation are reused.
- `action_agent` retains the existing agent graph and tools. Live prices, stock, availability, order status, product cards/links, quotes, complaints, human requests, ambiguous references and mixed requests use this route. Active scenario history, uncovered multimodal history, unusable memory snapshots and latest messages exceeding the configured hard token budget skip the classifier.
- Router errors/timeouts/invalid JSON or direct-pipeline failures fall back to the existing agent. Retrieval has no side effects. A generated handoff decision goes through the existing delivery/handoff lifecycle.

Copilot reply suggestions and runtime-configuration playground runs keep their existing behavior. The fast pipeline preserves business identity, guardrails, response guidelines, ownership instructions, language, channel limits, citation formatting and suggested replies. It does not generate live product cards.

## Migration

Deploy Rails migration `20261012120000_create_captain_conversation_memories` before starting the updated web/worker processes. No new credential is required when reusing the existing LiteLLM models. Both new clients inherit `CAPTAIN_OPEN_AI_ENDPOINT` and `CAPTAIN_OPEN_AI_API_KEY` configured in Super Admin. Requests use OpenAI-compatible Chat Completions through LiteLLM, with aliases resolved by the proxy, not the local model registry.

Prefer setting the model environment variables below to your existing Gemini 3.5 Flash-Lite LiteLLM alias. Creating duplicate deployments is unnecessary. Alternatively, logical role aliases can point at the same existing provider configuration. Example (provider credentials stay in LiteLLM's secret environment):

```yaml
model_list:
  - model_name: intent-router
    litellm_params:
      model: gemini/gemini-3.5-flash-lite
      api_key: os.environ/GEMINI_API_KEY
      reasoning_effort: minimal
  - model_name: knowledge-answer
    litellm_params:
      model: gemini/gemini-3.5-flash-lite
      api_key: os.environ/GEMINI_API_KEY
      reasoning_effort: minimal
```

Verify the installed LiteLLM version supports these model IDs and structured outputs. Disable proxy retries/fallback chains for the classification alias/key as well as in the client. Proxy retries can otherwise extend the classification deadline. Do not change the main assistant model when adding these aliases.

Configure Rails and Sidekiq consistently:

```dotenv
CAPTAIN_INTENT_ROUTING_MODE=shadow
CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS=1
CAPTAIN_INTENT_ROUTER_MODEL=intent-router
CAPTAIN_INTENT_ROUTER_TIMEOUT=1.5
CAPTAIN_KNOWLEDGE_ANSWER_MODEL=knowledge-answer
CAPTAIN_KNOWLEDGE_ANSWER_TIMEOUT=30
# Optional: otherwise the summary reuses CAPTAIN_KNOWLEDGE_ANSWER_MODEL
CAPTAIN_MEMORY_SUMMARY_MODEL=conversation-summary
CAPTAIN_ACTION_MEMORY_ENABLED=false
```

Start with `shadow`, which logs routing decisions while the existing agent answers. Switch to `on` after validating your languages, scenario boundaries and routing accuracy. Set `off` to restore the existing generation path. Use `CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS` to restrict rollout to selected accounts; blank enables all eligible accounts.

## Shared conversation memory

The reply pipeline uses an account/conversation/assistant-scoped `Captain::ConversationMemory` row. It contains a rolling summary, structured facts with source message IDs, covered-message cursor, source fingerprint, revision and summarizer version. Original Chatwoot messages remain the source of truth.

Initial budgets are conservative local token estimates, calculated from UTF-8 bytes rather than model-specific tokenization: recent messages about 3,000 tokens, background trigger 6,000, hard catch-up threshold 8,000, summary at most 700 and facts at most 500. Validate estimates against actual LiteLLM usage when tuning. Current customer messages and application ownership/action state always take priority over historical memory.

Normal replies enqueue low-priority compaction once the threshold is crossed. No summarization call is added on every reply. A pending summary retains every uncovered message after the last completed cursor. At the hard threshold the service attempts one synchronous catch-up with a two-second client timeout (`CAPTAIN_MEMORY_CATCH_UP_TIMEOUT`); failure or a still-oversized tail bypasses direct routing and retains the existing full-history agent path. Individual oversized or non-text messages are not silently truncated. Multimodal older segments are not summarized by this text-only compactor and therefore can keep a conversation on the full agent path.

Compaction updates previous memory with only newly eligible older messages, preserves recent complete exchanges, and processes large backlogs in bounded batches. It uses a Redis job mutex plus database revision/source checks; stale jobs cannot overwrite newer revisions or changed source messages. Source edits, deletions and resolution invalidate relevant memory. A stale response snapshot cannot erase newer compaction. Resolution boundaries clear the active workflow; older details can be recovered from original messages when explicitly requested.

`CAPTAIN_MEMORY_SUMMARY_MODEL` is an independent LiteLLM alias; by default it reuses the knowledge-answer alias. Set it to your existing Gemini alias initially; compare your existing GPT-6 Luna deployment if summary fidelity warrants it. Set `CAPTAIN_ACTION_MODEL` to the exact existing GPT-6 Luna LiteLLM alias after verifying its tools and structured output. This bypasses local registry lookup while retaining the same gateway credentials and endpoint, and applies to main/scenario agents (including channel-limit rewrites) only in enabled (`on`) accounts. If unset, the action model keeps its existing Captain configuration.

`CAPTAIN_ACTION_MEMORY_ENABLED=true` separately enables compacted history for action/scenario agents. Both the main agent and scenarios receive the same historical-memory prompt and an account-scoped tool for recovering original public messages by evidence ID or literal phrase. Private notes and deleted messages are excluded. Keep this option disabled during the first direct-routing rollout.

Memory rows are removed by cascading foreign keys when their account, conversation or assistant is deleted. Bulk changes bypassing Rails callbacks are detected by fingerprint validation before memory is used again.

The 1.5-second router timeout is a practical initial budget for combined classification and query generation, not a sub-300-ms guarantee. Tune only after measuring p50/p95 through your proxy; very short timeouts can cause most requests to fall back to the slower agent.

Logs contain assistant IDs, intent, queue wait, total generation, classifier, answer-generation and retrieval durations, without query text, credentials or provider error bodies. Compare these with existing Captain/LiteLLM generation traces and queue timing. Local canned results and direct generation preserve agent-session sources and label their actual generation model.

## Acceptance checks

Validate greetings, long multipart knowledge questions, product references in follow-ups, no-match retrieval, policy guardrails, mixed live-data requests, active scenarios, resolution boundaries, attachments, explicit human requests, proxy timeouts, invalid router JSON, citations, ownership changes and newer messages arriving during generation. Benchmark end-to-end latency and the rate of unsafe knowledge routing before rollout.

Model lifecycle references (checked October 11, 2026):

- Google stable Flash-Lite: https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite
- Google deprecations: https://ai.google.dev/gemini-api/docs/deprecations
- Groq deprecations (Llama 3.1 8B is enterprise-only): https://console.groq.com/docs/deprecations
- LiteLLM routing/retries: https://docs.litellm.ai/docs/routing

## Local validation

The implementation was checked with 344 existing regression examples, plus temporary validation harnesses exercising LiteLLM payloads, source indexes, parallel retrieval, summary persistence, incremental updates, resolution boundaries, source invalidation, account isolation, revision races, suggestion buttons, original-source lookup and summary failure fallback. No live provider latency or routing-accuracy benchmark has been run. See the conversation-memory plan for external provider candidates; adding another provider is optional.
