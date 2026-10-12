# Captain Langfuse tracing

Chatwoot owns response traces because it can observe routing, retrieval, models, tool execution, scenario handoffs, rewriting and delivery. LiteLLM-only logging sees model requests but not the surrounding application work.

The repository already contained an OTLP Langfuse exporter and ai-agents instrumentation. This change completes the new tiered routing path and adds a dedicated control page; no new dependency or database migration is required.

## Setup

After deploying this change, open **Super Admin → Settings → AI Observability**:

- Provider: Langfuse.
- Base URL: `https://langfuse.yoshovski.com` (the existing self-hosted instance).
- Public/secret keys: enter the target Langfuse project's keys in the masked fields. Never put keys into logs, documentation or shell commands.
- Enable Langfuse Tracing: True.
- Capture Trace Content: False for metadata only; True to inspect prompts, replies, retrieval text and tool inputs/results.

Restart Rails and Sidekiq after changing the provider, URL or credentials. The two boolean switches apply without restart and also affect background export of queued spans. Already exported traces remain in Langfuse; an export already in flight can finish after disabling. `LANGFUSE_TRACING_ENABLED=false` in the environment forces tracing off regardless of the database switch and needs restart to change.

The standard installation config reconciliation creates the new settings on upgrade. Keys are stored using the existing installation-config mechanism; masked fields do not imply database encryption.

## Trace coverage

- `captain.delivery`: response job, source message ID, queue delay and conversation session.
- `captain.response`: generation, routing, channel rewrites, outcome and discard decision.
- `captain.classify`, `captain.knowledge_answer`, `captain.summarize`: full call-duration generation observations, LiteLLM alias and returned token usage.
- `captain.knowledge.search`: Rails knowledge-service request, query, selected source references, scores and results. Parallel searches preserve their parent context.
- Existing SDK agent observations: main/scenario agents, individual model generations, tool names/inputs/results and handoff events. The SDK emits observations at completion; a Chatwoot hook records the start of each RubyLLM completion so exported model spans include the request duration, including recursive calls after tools. Direct-call generation durations are also measured across the actual request.
- `captain.memory.compaction`: background summary work grouped into the same account/conversation session. Each background job has its own trace rather than remaining attached to a finished response trace.

Public tools execute with their SDK tool span as the active parent, so nested retrieval can be linked to the originating tool. Traces describe tool calls and returned outcomes; they do not independently verify an external mutation.

Dify's internal embedding/reranking steps, Shopify's internal HTTP processing and LiteLLM's provider retries are not instrumented inside those services by this change. Chatwoot sees request/tool boundaries and outcomes. A separate distributed tracing integration would be needed for their internal spans.

## Export and content

Uses existing OpenTelemetry SDK and OTLP/HTTP exporter, with asynchronous batches and Langfuse ingestion version 4. No flush or Langfuse network request is added to the response path. Metadata-only mode removes content-bearing attributes from every instrumentation source, including ai-agents. Returned model aliases and token usage remain available; custom alias costs require Langfuse model-price configuration.

The exporter removes recognized credential fields, bearer strings, common key/value secret patterns and known key prefixes, drops exception events and replaces error status messages. Content capture still contains customer data and tool results; inspect the resulting traces with your real tools before enabling it broadly. Content is capped per string at 32,000 characters. Full action credentials, request headers and configured tool authentication are not intentionally added to traces.

Tracing wrappers never replay a failed business operation. Legacy instrumentation was corrected to distinguish a failed operation from a tracing failure before invocation.

## Validation

Validate metadata-only and content modes, live disable/enable, router/answer usage, action tools/handoffs, query-thread parent IDs, summary sessions and exporter failures. Local validation passed 201 existing regression examples, 33 targeted checks (including a real mocked SDK tool cycle), and five request examples with asset tags stubbed to isolate the settings form. The self-hosted health endpoint reports healthy, version 3.225.7. Authenticated ingestion remains unverified: use a harmless conversation to verify it in the configured Langfuse project after deployment.

Official transport and attribute reference: https://langfuse.com/integrations/native/opentelemetry
