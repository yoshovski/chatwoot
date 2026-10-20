# Website discovery and broad business answers

## Existing agents

Deploying this change does not discover or import additional pages for any existing agent. Existing source selections, datasets, prompts, models and routing settings are preserved. The shared parser fixes selection of a `<main>` inside `<noscript>` or `<template>`; subsequent explicit crawls and scheduled refreshes benefit from the fix. No existing document is automatically reindexed by deployment.

Business overviews and topic summaries are off by default. They affect an agent only after an administrator generates a draft, reviews it and chooses **Publish & enable for this agent**. Disabling summaries restores the original prompt context. There is no global enable switch or migration backfill.

## Discover, select and import

In an agent's Knowledge documents, **Add a document → Entire website** starts a durable discovery job. **Single page** imports that page alone and never starts website discovery. Existing API callers retain their explicit `include_linked_pages` behavior.

Discovery combines conventional and robots-advertised sitemaps, nested sitemap indexes (including gzip), recursive links, and optional Firecrawl Map when its existing installation credential is configured. Subdomain discovery can be disabled. Domain boundaries use the Public Suffix List; suffix lookalikes and unrelated external links are excluded. Fetches use SafeFetch's SSRF and redirect protection. Credentials and nonstandard ports are rejected in website source URLs.

Pages wait in per-section queues (host plus first path segment) and are fetched round-robin, so every section is sampled before one large blog or docs tree uses the request budget. Technical hosts (API, auth, sandbox, status, demo, connector and similar subdomains), utility paths (account, cart, search, sign-in) and query URLs are listed but never fetched; other-language copies of the start page's language are skipped too. Each fetched page records quality signals from the same main content the import keeps: word count, link density, language, canonical link, `noindex`, sign-in forms, JSON-LD types and a text fingerprint.

Zendesk Guide help centres (any `/hc/` URL) are read through their public Help Center API instead of crawling: every published article in the default locale is listed with its section name and word count, and imports use the article body from the API, falling back to the page when the API is restricted. robots.txt is honoured for the API as for pages.

## Recommended, maybe and excluded

Every page lands in one bucket. **Excluded** pages carry a reason: technical site, utility page, list of links, filtered URL, not a web page, hidden from search (`noindex`), behind sign-in, duplicate (canonical link or same text as a shorter URL), very little text (under 60 words), other language, not useful, blocked by robots.txt or managed by the product catalog. Administrators can still select excluded pages except the last two. Without section labels, pages on the entered host, help-centre articles and support-like hosts (support, help, docs, developers, kb, faq…) are **Recommended**; everything else is **Maybe**.

When discovery finishes, one background model call labels up to 120 sections from their page counts, sample titles, descriptions and average length, together with the agent's name and description: support, product, docs, pricing, legal, company, news, marketing, technical or not useful, with a recommendation and a one-sentence reason. Labels refine the buckets; `not_useful` sections become excluded. Website text is treated as untrusted. If the call fails the rule-based buckets stay and the UI says so. `CAPTAIN_KNOWLEDGE_CLASSIFIER_MODEL` chooses the model and defaults to the summary, then the answer model.

The browser shows Recommended, Maybe, Excluded and All tabs as a host → section → page tree with section labels and exclusion reasons, plus a preview of the text that would become knowledge (v2 cleaning applied) with its word count. Recommended pages start selected once sorting finishes, unless a selection already exists or the administrator has changed it. Selections can be saved while discovery is still running; the footer shows how many new documents the selection needs against the plan's remaining quota. Discovery alone never creates knowledge documents. Imports use the existing document quota, indexing, status, source citations and account refresh settings. Selected imports are staggered rather than fetched in one burst. Shopify product and collection paths remain owned by catalog synchronization; discovered copies are not selectable.

Saving selections creates missing documents and resumes website-managed documents. Deselecting pauses website-managed documents unless another website source still selects them; pre-existing manual documents are preserved. Re-discovery preserves selections, and newly discovered URLs await explicit selection. Disabled website imports skip scheduled refresh work. Original content remains available in the document library.

Robots rules are checked during discovery and again before imported pages are fetched. Firecrawl performs JavaScript rendering when configured; otherwise a detected JavaScript-only shell fails with `rendering_required` instead of becoming knowledge. The Cleeng homepage can be extracted without JavaScript after the parser fix. Individual PDF/file uploads retain their existing flow; website discovery lists web pages rather than downloadable assets.

Discovery is bounded to 2,000 page URLs, 500 HTML requests, 40 sitemap requests, 40 origins and ten minutes. The UI names each limit that was reached. Pages on origins past the origin limit stay unchecked rather than being marked blocked by robots.txt; the import checks robots.txt again before fetching. Sitemap, map and help-centre pages are checked against every robots.txt read during the run.

At import, a page whose cleaned text has fewer than 25 words fails with `thin_content`, and a page whose text another enabled document of the agent already holds fails with `duplicate_content`, instead of becoming knowledge. A narrower source can explore another section. Discovery uses the low-priority queue, and the browser can be closed while it runs. Failed discovery can be restarted; a pending job older than two hours can be recovered through **Discover again**.

## Business overview and topic summaries

**Review overview** lists only this agent's enabled, public, ready documents. Choose up to 60 representative sources, then generate a draft. Background generation summarizes batches and merges them into a business overview (1,500 characters) and up to eight complementary topics (800 characters each). The source excerpts used for generation are bounded to 12,000 characters per document; detailed retrieval continues to search the full knowledge library. Select concise overview/product/policy documents for broad coverage.

Drafts are editable, retain supporting document IDs and require explicit publishing. The published brief adds bounded business context to the agent's prompt. When existing intent routing is enabled, a new `business_overview` route answers broad company/capability/use-case questions from approved summaries without another knowledge search; detailed questions retain the existing RAG route, and actions retain their existing workflow. Existing routing enablement and account allowlists are unchanged. Summary evidence uses the existing source-index and session tracking infrastructure.

Every use verifies the source set and content fingerprint against the same account and agent. Changed, disabled, deleted, private or no-longer-ready sources immediately make the published brief unusable. Source changes enqueue a replacement draft for opted-in agents; that draft must be reviewed and published before it is used. Existing published text is never silently overwritten. Publishing checks the draft revision to reject superseded review screens.

There is no conversation-learning loop: visitor statements and private messages never enter these business summaries. Generation and source refresh do not add model calls to ordinary replies. The original 500-character agent description remains editable and unchanged.

## Deployment

Concurrent initial Dify imports can encounter PostgreSQL lock or statement timeouts while dataset creation waits for the embedding provider. Provisioning and document sync retry these database timeouts with a bounded delay. Exhausted document retries mark the document failed instead of leaving it indefinitely syncing. Dify HTTP failures retain their existing handling; provider outages still require recovery.

Run Rails migration `20261020120000_create_captain_website_sources` before restarting the web and worker containers. It adds `captain_website_sources` and `captain_knowledge_briefs`; it does not modify existing sources or opt in any agent. Ship web, worker and compiled frontend together. No knowledge-service or Dify database migration is needed.

Optional `CAPTAIN_KNOWLEDGE_SUMMARY_MODEL` chooses the background generation model and defaults to `CAPTAIN_KNOWLEDGE_ANSWER_MODEL` (or `knowledge-answer`). It uses the existing Captain/LiteLLM credential and account usage headers. No new provider credential is required. Firecrawl configuration is optional and remains installation-managed.

If Compose enumerates environment keys explicitly, pass the optional summary model key to both web and worker services. Leaving it unset uses the existing answer model.

For Cleeng, first create a new agent, discover its website, select the appropriate main-site/support/developer pages, and wait until documents are ready. Generate the business brief from representative public sources, review it and publish only for that agent. Test broad questions, technical questions, audience distinctions, greetings and unsupported requests before attaching it to a live inbox. No Scanixx changes are required.

Rollback: disable the brief for the affected agent first. Deselect website-managed pages to pause them if needed. The migration is additive; ordinary application rollback can leave the new tables in place, preserving selections and drafts for a later rollout.

## Versioned cleaning and grounded FAQs

New AI agents default to `config.knowledge_processing_version = 2`. Existing agents without that value retain the previous processing, including fingerprints and plain-line heading inference. There is no migration or bulk reindex. An operator may opt in a specific existing agent and explicitly sync its sources; the Cleeng rollout uses this path. Scanixx remains on its existing processing.

Version 2 removes image markup while preserving alternative text, deduplicates repeated paragraphs within their heading context, and identifies pages dominated by short interface fragments. Those noisy pages are curated in bounded background batches. The model selects numbered source paragraphs; the application copies original text, rejecting invalid references. It excludes demo interfaces and example prices rather than teaching them as company pricing. Raw crawl text and its fingerprint remain in the source metadata for inspection and unchanged-source reuse. Curation failure leaves a visible failed sync rather than indexing unreviewed noise. Clean prose and legal documents retain their text without an extra curation model call.

Version 2 uses actual Markdown headings rather than promoting short UI labels into headings, and numeric metric headings remain attached to their explanations. Parent sections retain their paragraphs and use Dify's existing 2,400-token parent / 768-token child limits. Text fingerprints use `sectioned-v5`; legacy fingerprints remain `sectioned-v4`.

After Dify completes indexing, website imports automatically generate up to twelve grounded FAQs. The model selects an existing source paragraph as evidence; that exact paragraph becomes the answer. Unsupported references are rejected. Source fingerprints and response IDs are retained in document metadata. Unedited generated FAQs are replaced when regenerated, edited FAQs are preserved, and stale generated answers are rejected by canonical retrieval as soon as their source content changes. Current generation considers the first 48,000 source characters and evidence paragraphs of 40–2,000 characters; full-document RAG remains available for the rest.

`CAPTAIN_KNOWLEDGE_CURATION_MODEL` and `CAPTAIN_KNOWLEDGE_FAQ_MODEL` optionally override the background models; both default to the existing `CAPTAIN_KNOWLEDGE_ANSWER_MODEL` alias. No global model/routing change is needed.

## Automatic KB provisioning and recovery

Creating an AI agent with Dify enabled queues automatic creation of its FAQ and Documents datasets. Account creation alone does not create these agent-specific datasets. Provisioning now retries Dify failures with bounded backoff as well as PostgreSQL lock/statement timeouts. The assistant's generated provisioning identity is persisted before external creation and omitted from client configuration. Dataset descriptions contain a per-kind identity; retries search the authenticated workspace for that exact identity and recover a successful creation whose response was lost. Duplicate matching identities fail rather than choosing an ambiguous dataset. Already-configured agents are not modified. Document ingestion provisions outside its document transaction, avoiding a long document row lock while waiting for initial dataset setup.
