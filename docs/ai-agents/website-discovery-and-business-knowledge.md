# Website discovery and broad business answers

## Existing agents

Deploying this change does not discover or import additional pages for any existing agent. Existing source selections, datasets, prompts, models and routing settings are preserved. The shared parser fixes selection of a `<main>` inside `<noscript>` or `<template>`; subsequent explicit crawls and scheduled refreshes benefit from the fix. No existing document is automatically reindexed by deployment.

The business profile (overview and topic summaries) is off by default. It affects an agent only after an administrator generates a draft in Settings → Identity, reviews it and chooses **Publish**. Disabling summaries restores the original prompt context. There is no global enable switch or migration backfill.

## Discover, select and import

In an agent's Knowledge documents, **Add a document → Entire website** starts a durable discovery job. **Single page** imports that page alone and never starts website discovery. Existing API callers retain their explicit `include_linked_pages` behavior.

Discovery combines conventional and robots-advertised sitemaps, nested sitemap indexes (including gzip), recursive links, and optional Firecrawl Map when its existing installation credential is configured. Subdomain discovery can be disabled. Domain boundaries use the Public Suffix List; suffix lookalikes and unrelated external links are excluded. Fetches use SafeFetch's SSRF and redirect protection. Credentials and nonstandard ports are rejected in website source URLs.

Pages wait in per-section queues (host plus first path segment) and are fetched round-robin, so every section is sampled before one large blog or docs tree uses the request budget. Technical hosts (API, auth, sandbox, status, demo, connector and similar subdomains), utility paths (account, cart, search, sign-in) and query URLs are listed but never fetched; other-language copies of the start page's language are skipped too. Each fetched page records quality signals from the same main content the import keeps: word count, link density, language, canonical link, `noindex`, sign-in forms, JSON-LD types and a text fingerprint.

Zendesk Guide help centres (any `/hc/` URL) are read through their public Help Center API instead of crawling: every published article in the default locale is listed with its section name and word count, and imports use the article body from the API, falling back to the page when the API is restricted. robots.txt is honoured for the API as for pages.

## Recommended, optional and skipped

The picker tabs are **Recommended**, **Optional** and **Skipped** (internally `recommended`, `maybe` and `excluded`). Every page lands in one bucket. **Skipped** pages carry a reason: technical site, utility page, list of links, filtered URL, not a web page, hidden from search (`noindex`), behind sign-in, duplicate (canonical link, or the same or nearly the same text as a shorter URL: pages sharing at least 75% of their word shingles, estimated from a 32-value MinHash), very little text (under 60 words), other language, not useful, blocked by robots.txt or managed by the product catalog. Administrators can still select skipped pages except the last two. Pages that were not found, have no text or are not web pages are not listed at all; the picker only says how many were left out. Only pages whose text was read can be recommended; unread pages are **Optional**. Without labels, read pages on the entered host, help-centre articles and support-like hosts (support, help, docs, developers, kb, faq…) are **Recommended**; everything else is **Optional**.

When discovery finishes, one background model call labels up to 120 sections from their page counts, sample titles, descriptions and average length, and up to 100 pages that are a section of their own (start host first), together with the agent's name and description: support, product, docs, pricing, legal, company, news, events, careers, marketing, technical or not useful, with a recommendation and a one-sentence reason. Careers, events, contract schedules, data processing agreements, sub-processor lists and cookie policies are not recommended; a page label wins over its section's. Labels refine the buckets; `not_useful` sections become excluded. Website text is treated as untrusted. If the call fails the rule-based buckets stay and the UI says so. `CAPTAIN_KNOWLEDGE_CLASSIFIER_MODEL` chooses the model and defaults to the summary, then the answer model.

The browser shows Recommended, Maybe, Excluded and All tabs as a host → section → page tree with section labels and exclusion reasons, plus a preview of the text that would become knowledge (v2 cleaning applied) with its word count. Recommended pages start selected once sorting finishes, unless a selection already exists or the administrator has changed it. Selections can be saved while discovery is still running; the footer shows how many new documents the selection needs against the plan's remaining quota. Discovery alone never creates knowledge documents. Imports use the existing document quota, indexing, status, source citations and account refresh settings. Selected imports are staggered rather than fetched in one burst. Shopify product and collection paths remain owned by catalog synchronization; discovered copies are not selectable.

Saving selections creates missing documents and resumes website-managed documents. Deselecting pauses website-managed documents unless another website source still selects them; pre-existing manual documents are preserved. Re-discovery preserves selections, and newly discovered URLs await explicit selection. Disabled website imports skip scheduled refresh work. Original content remains available in the document library.

Robots rules are checked during discovery and again before imported pages are fetched. Firecrawl performs JavaScript rendering when configured; otherwise a detected JavaScript-only shell fails with `rendering_required` instead of becoming knowledge. The Cleeng homepage can be extracted without JavaScript after the parser fix. Individual PDF/file uploads retain their existing flow; website discovery lists web pages rather than downloadable assets.

Discovery is bounded to 2,000 page URLs, 500 HTML requests, 40 sitemap requests, 40 origins and ten minutes. The UI names each limit that was reached. Pages on origins past the origin limit stay unchecked rather than being marked blocked by robots.txt; the import checks robots.txt again before fetching. Sitemap, map and help-centre pages are checked against every robots.txt read during the run.

After discovery, a background check requests every listed page that was never opened (from sitemaps, maps or links; up to 1,000 pages within ten minutes, robots.txt respected). The first 150, taken round-robin per section, are read in full and measured like discovered pages, so a section can still be recommended; the rest are only checked for their status. Pages answering 404 or 410 move to Excluded as **Page not found**, and 401 or 403 as **Behind sign-in**. The picker shows **Not checked** on pages not yet verified, and recommended pages are pre-checked only after this check and the section labels finish.

At import, a page whose cleaned text has fewer than 25 words fails with `thin_content`, and a page whose text another enabled document of the agent already holds fails with `duplicate_content`, instead of becoming knowledge. When this happens on a page's first import (or the page is not found, needs sign-in or is disallowed by robots.txt), the document is removed instead of staying as a failed document: the page is deselected and shown in Excluded with the reason, so it uses no document quota and is not retried by scheduled refreshes. A page that was imported before and later fails keeps its last content and shows the failure. A narrower source can explore another section. Discovery uses the low-priority queue, and the browser can be closed while it runs. Failed discovery can be restarted; a pending job older than two hours can be recovered through **Discover again**.

## Business profile (overview and topics)

The business profile lives in the agent's **Settings → Identity**, next to the description it extends. It is a business overview of at most 1,000 characters and 3–5 topics of at most 400 characters each, written only from the agent's public, ready knowledge. It is used for broad questions ("What do you do?"): it is added to the agent's instructions, and when intent routing is enabled the `business_overview` route answers broad company/capability questions from it without another knowledge search. Detailed questions still search the full knowledge library.

**Generate from knowledge** lets one model call choose 8–20 sources from up to 300 document titles and URLs (shortest URLs first; about, product, pricing, policy and support overviews preferred; blog posts, release notes and narrow how-tos skipped). If that call fails, the 20 top-level pages are used. **Choose sources** picks up to 60 sources by hand; sources still being indexed are left out of the draft instead of failing it. Drafts are editable, topics can be removed, every overview and topic cites its source documents, and nothing is used until **Publish**.

A published profile stays in use while all of its sources still exist, are enabled and are public. When a source's content changes, the profile keeps working, the panel says the sources changed, and a replacement draft is generated in the background for review. Deleting, disabling or making a source private pauses the profile until a new draft is published. Visitor messages never enter the profile. `CAPTAIN_KNOWLEDGE_SUMMARY_MODEL` chooses the model for picking sources and writing drafts.

## Deployment

Concurrent initial Dify imports can encounter PostgreSQL lock or statement timeouts while dataset creation waits for the embedding provider. Provisioning and document sync retry these database timeouts with a bounded delay. Exhausted document retries mark the document failed instead of leaving it indefinitely syncing. Dify HTTP failures retain their existing handling; provider outages still require recovery.

Run Rails migration `20261020120000_create_captain_website_sources` before restarting the web and worker containers. It adds `captain_website_sources` and `captain_knowledge_briefs`; it does not modify existing sources or opt in any agent. Ship web, worker and compiled frontend together. No knowledge-service or Dify database migration is needed.

Optional `CAPTAIN_KNOWLEDGE_SUMMARY_MODEL` chooses the background generation model and defaults to `CAPTAIN_KNOWLEDGE_ANSWER_MODEL` (or `knowledge-answer`). It uses the existing Captain/LiteLLM credential and account usage headers. No new provider credential is required. Firecrawl configuration is optional and remains installation-managed.

If Compose enumerates environment keys explicitly, pass the optional summary model key to both web and worker services. Leaving it unset uses the existing answer model.

For Cleeng, first create a new agent, discover its website, select the appropriate main-site/support/developer pages, and wait until documents are ready. Generate the business profile from knowledge in Settings → Identity, review it and publish only for that agent. Test broad questions, technical questions, audience distinctions, greetings and unsupported requests before attaching it to a live inbox. No Scanixx changes are required.

Rollback: disable the brief for the affected agent first. Deselect website-managed pages to pause them if needed. The migration is additive; ordinary application rollback can leave the new tables in place, preserving selections and drafts for a later rollout.

## Versioned cleaning and grounded FAQs

New AI agents default to `config.knowledge_processing_version = 3` (see below); agents created while version 2 was the default keep version 2. Existing agents without that value retain the previous processing, including fingerprints and plain-line heading inference. There is no migration or bulk reindex. An operator may opt in a specific existing agent and explicitly sync its sources; the Cleeng rollout uses this path. Scanixx remains on its existing processing.

Version 2 removes image markup while preserving alternative text, deduplicates repeated paragraphs within their heading context, and identifies pages dominated by short interface fragments. Those noisy pages are curated in bounded background batches. The model selects numbered source paragraphs; the application copies original text, rejecting invalid references. It excludes demo interfaces and example prices rather than teaching them as company pricing. Raw crawl text and its fingerprint remain in the source metadata for inspection and unchanged-source reuse. Curation failure leaves a visible failed sync rather than indexing unreviewed noise. Clean prose and legal documents retain their text without an extra curation model call.

Version 2 uses actual Markdown headings rather than promoting short UI labels into headings, and numeric metric headings remain attached to their explanations. Parent sections retain their paragraphs and use Dify's existing 2,400-token parent / 768-token child limits. Text fingerprints use `sectioned-v5`; legacy fingerprints remain `sectioned-v4`.

After Dify completes indexing, website imports only import the Q&A the page itself contains. Grounded AI FAQs are generated when an administrator chooses **Suggest FAQs** for a document or a section: up to twelve per page, skipping answers another FAQ of the agent already has. The model selects an existing source paragraph as evidence; that exact paragraph becomes the answer. Unsupported references are rejected. Source fingerprints and response IDs are retained in document metadata. Unedited generated FAQs are replaced when regenerated, edited FAQs are preserved, and stale generated answers are rejected by canonical retrieval as soon as their source content changes. Current generation considers the first 48,000 source characters and evidence paragraphs of 40–2,000 characters; full-document RAG remains available for the rest.

`CAPTAIN_KNOWLEDGE_CURATION_MODEL` and `CAPTAIN_KNOWLEDGE_FAQ_MODEL` optionally override the background models; both default to the existing `CAPTAIN_KNOWLEDGE_ANSWER_MODEL` alias. No global model/routing change is needed.

## Version 3: site-independent cleaning and packed chunks

Version 3 keeps everything version 2 does (deduplication, model curation of noisy pages, grounded FAQs) and adds deterministic cleaning that works on any website before any model call:

- Links are kept where the agent can share them. A paragraph with up to three links keeps them inline as `[text](absolute URL)`; denser prose (encyclopedia style) keeps the link text only. Buttons and link lists leave the passage, and their targets are listed once in a `## Links` section at the end of the page (at most 20, HTTPS preferred). Links are made absolute, tracking parameters (`utm_*`, HubSpot `hs*`, `fbclid`, `gclid`…) and fragments are removed, and in-page anchors, scripts, the page itself, labels that are URLs and labels repeated three or more times ("Learn more", "edit") are skipped. Site-wide menus learned as boilerplate do not feed the Links section except on the start page. Images are removed unless their alternative text is a descriptive phrase (logos, icons and file names never are). `**`/`__` markers and zero-width characters are removed.
- Navigation and link lists, call-to-action buttons (short lines that are links or repeat on the page, such as "See a demo"), card-link wrappers, copyright lines, and headings left without content are dropped. A short line used once and followed by a real paragraph stays as that paragraph's title.
- Discovery learns, per host, the text blocks that appear on at least 30% of fetched pages (minimum four pages): menus, banners and calls to action outside `<nav>`/`<footer>`. They are removed from every page of that website source except its start page, so a site-wide fact is still indexed once. It also learns blocks on at least half of one section's pages (minimum three), such as an ebook banner on every `/resources` page, and keeps those only on the section's shortest URL. The block hashes live in `discovery_stats.boilerplate` and `discovery_stats.boilerplate_sections` and are not sent to the browser.

Chunking packs the page instead of making one parent per heading. Parents (the context returned to the model) hold neighbouring sections up to about 3,000 characters and start again at a new top-level topic once they have 800. Children (what is embedded) are paragraphs packed up to about 800 characters, each starting with a short context line: the page title and the two nearest headings, without Markdown. One-line sections join their neighbour with only the differing part of their context line. Captain separates children with a blank line and Dify's child separator is a blank line for these documents, so Dify keeps Captain's boundaries exactly; PDFs keep token-based splitting. Fingerprints use `packed-v1`.

Measured on nine real pages (product, help-centre, developer, government, retail and encyclopedia sites), version 3 produced one to nine parents per page instead of up to 22 one-section parents, children of 470–735 characters on average, and one child under 200 characters in total.

To move an existing agent, run `ACCOUNT_ID=… ASSISTANT_ID=… bundle exec rake captain:knowledge:upgrade_processing`. It sets version 3, re-cleans each enabled website page from its stored crawl (version 1 pages use their current content), and queues Dify reindexing. Learned boilerplate applies to pages of website sources discovered after this change; rediscover a source to learn it.

## Automatic KB provisioning and recovery

Creating an AI agent with Dify enabled queues automatic creation of its FAQ and Documents datasets. Account creation alone does not create these agent-specific datasets. Provisioning now retries Dify failures with bounded backoff as well as PostgreSQL lock/statement timeouts. The assistant's generated provisioning identity is persisted before external creation and omitted from client configuration. Dataset descriptions contain a per-kind identity; retries search the authenticated workspace for that exact identity and recover a successful creation whose response was lost. Duplicate matching identities fail rather than choosing an ambiguous dataset. Already-configured agents are not modified. Document ingestion provisions outside its document transaction, avoiding a long document row lock while waiting for initial dataset setup.

## Large imports, failed syncs and section management

Dify indexes uploads one after another, so a large import can wait in its queue. Polling backs off from every 5 seconds to every 2 minutes and gives up after about two hours (`dify_indexing_timeout`); the 5-minute scheduler then rechecks timed-out documents for seven days and marks them Ready once Dify has finished. A failed document shows the reason and offers **Retry**: a Dify failure resends the stored text (or only polls when Dify already indexed it), and a website page whose first import failed is fetched again. Exhausted dataset provisioning marks the agent's waiting documents failed.

Deleting an AI agent deletes its two Dify datasets unless another agent uses them. Provisioning takes over a dataset with the expected name (an agent recreated with a deleted agent's name) when no agent references it and it uses the account's embedding model, instead of failing on Dify's duplicate-name error.

When an agent has at least ten documents in several sections, the documents page shows a **Sections** panel: documents grouped like discovery (host and first path segment, files apart) with ready, failed and paused counts. Selected sections can be paused, resumed, retried, deleted or get suggested FAQs in one action; pausing and deleting also update the website selection so the picker does not import them again. A section can filter the list.

`rake captain:knowledge:dedupe_generated_faqs ACCOUNT_ID=… ASSISTANT_ID=… DRY_RUN=1` lists unedited AI-generated FAQs whose answer repeats another FAQ of the agent; without `DRY_RUN` it deletes them. Page-imported, manual and edited FAQs are never touched.

## Sources shown to the team

The model always reports which results each reply part relies on (`citation_indexes`). `feature_citation` only decides whether customers see citations; the conversation's **Sources** panel works either way. A reply that cites nothing still marks a source as matched when a reply sentence of at least eight words is mostly found in that source's text. The panel says "No source matched this reply" and lists the other results under "Also searched".

## Business profile sources

**Generate from knowledge** stores a short reason for every source the model picks. **Choose sources** lists the suggested sources first with that reason, groups the others by website section, and offers search, **Select suggested** and **Clear**.

## Deployment of the knowledge-quality update

No migration. Ship web, worker and compiled frontend together. Existing website sources get page labels, MinHash duplicates, section boilerplate and measured recommendations after **Discover again**; then `rake captain:knowledge:upgrade_processing` re-cleans pages with the section boilerplate. Run the FAQ dedupe task with `DRY_RUN=1` first. Documents already marked `dify_indexing_timeout` are rechecked automatically.
