# AI Agents development

The Huly project **CWAI — Chatwoot AI Agents** tracks this initiative.

- [Architecture and phased delivery](architecture.md).
- [Internal release baseline and lab gates](internal-release-baseline.md).
- [Huly architecture document](https://pm.yoshovski.com/workbench/yoshovski/document/architecture-and-phased-release-plan-chatwoot-ai-agents-6abf135fae4c92239df5cfba).

Website chat is the first channel. Dify is the selected server-side retrieval backend. Client-managed agents and editable/exportable knowledge are independent of Captain's content model. Shopify catalog indexing remains integration-owned. Usage is a fixed, account-scoped 24-hour service window with manual plans before payments.

CWAI-1 establishes the upstream 4.18.0 baseline while preserving the deployed internal customization history. The next implementation tasks are CWAI-2 (canonical knowledge records and Dify projection) and CWAI-3 (native FAQ management/import/export).

All builds enter the lab as immutable release candidates. Production promotion follows lab acceptance and a separate release decision. A baseline upgrade does not enable the future AI service, change the active n8n workflow, or enforce new customer quotas.
