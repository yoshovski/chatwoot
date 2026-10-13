# Tenant consumption in LiteLLM

ChatOctave accounts can share an organization, team and virtual key without sharing a customer identity. The app sends request-local headers on its AI requests:

```text
x-litellm-customer-id: chatoctave-account-42
x-litellm-tags: chatoctave-account-42,feature:embedding
```

The account ID comes from the server-owned account/assistant/document, never a browser field or customer message. No names, emails, company names or message text are added to attribution. Header configuration is attached to each chat, agent or embedding provider instance; global SDK configuration is never changed per tenant. Agent tool continuations and scenario handoffs keep their account identity.

Set `LITELLM_TENANT_ID_PREFIX` to a unique installation prefix if multiple ChatOctave installations share the gateway. Its default is `chatoctave`. Keep it stable after rollout; changing it splits customer history. These headers are understood by LiteLLM; direct providers do not provide LiteLLM customer reporting. LiteLLM does not forward client headers to model providers by default.

## Find a customer's spend

1. Find the account ID in **Super Admin → Accounts → the customer's account** (the ID is in its URL).
2. Open LiteLLM **Usage → Customer Usage** and select `chatoctave-account-<ID>` in the customer filter. The documented Customer Usage UI requires **v1.80.8-stable or newer**.
3. Review spend, requests, tokens and model usage for the same date range. Customer/end-user identity is distinct from the internal user who owns the virtual key and from its team.
4. Inspect request logs for that customer. Tags additionally identify feature-level activity. LiteLLM documents tag-spend analytics as an enterprise feature; use customer filtering as the primary mechanism rather than depending on an enterprise license.

The app-owned paths covered are Captain V1/V2 chat, scenario agents and tool continuations, copilot suggestions, intent routing, direct answers, conversation memory, handoff summaries, document/PDF FAQ generation, assistant tasks and legacy Captain embeddings. This does not create new virtual keys or change existing team budgets.

Conversation allowance on the customer Usage & billing page is **not** token spend: it counts billable 24-hour conversation windows. Keep gateway cost reporting available to operators, separate from the customer's allowance and invoice.

## Dify embeddings and reranking

Native knowledge search and indexing delegate embeddings and reranking to Dify. Dify's dataset retrieval API in this integration accepts the query and retrieval configuration; this app does not make the resulting LiteLLM model calls. An `x-litellm-customer-id` header sent to Dify's retrieval endpoint must not be assumed to propagate into its provider/plugin requests or asynchronous indexing jobs.

For those costs, choose one of these explicit deployment arrangements:

- **Dedicated tenant workspace/provider credentials:** create a LiteLLM virtual key for the customer **within the existing team**, give it an account-based alias, and configure that key for all Dify embedding/query-embedding/reranking model credentials in a dedicated Dify workspace. Map the ChatOctave account to that workspace through the existing Super Admin Dify workspace settings. Filter the key alias in LiteLLM Usage. The organization and team remain shared. Using one key for multiple tenants in one shared Dify workspace still mixes their retrieval costs.
- **Shared Dify workspace:** provider/plugin and Dify job changes must carry the originating ChatOctave account through synchronous retrieval and asynchronous indexing and attach it to the actual LiteLLM embedding/rerank call. A Dify workspace ID identifies only the workspace, not the ChatOctave tenant. This requires a separate Dify integration change; the app cannot implement it merely by adding an HTTP header to dataset retrieval.

Dedicated keys are the available configuration route without changing Dify. This PR deliberately does not claim that its app headers attribute Dify-owned requests. Confirm attribution with one chat, one indexing operation and one reranked search per tenant before treating gateway totals as complete customer costs. Cached retrieval can produce no model request and therefore no additional gateway spend.

## Rollout verification

After deployment, make requests for two different accounts and confirm two customer IDs in LiteLLM. Compare their model-level request logs against the actual configured endpoint. Verify Dify costs separately by key alias for the dedicated-workspace arrangement. Existing mixed historical requests cannot be reconstructed reliably from the team key alone; tracking starts with attributed requests.

Primary references researched 2026-10-13:

- [LiteLLM Customer Usage](https://docs.litellm.ai/docs/proxy/customer_usage)
- [LiteLLM request headers](https://docs.litellm.ai/docs/proxy/request_headers)
- [LiteLLM spend tracking](https://docs.litellm.ai/docs/proxy/cost_tracking)
- [Dify OpenAI-compatible provider configuration](https://github.com/langgenius/dify-official-plugins/blob/main/models/openai_api_compatible/provider/openai_api_compatible.yaml)

Deployed LiteLLM/Dify versions and live spend accounting must be checked during rollout; local validation verifies the outbound SDK headers against fixture endpoints.
