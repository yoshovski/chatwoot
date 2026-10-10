# Dify workspace binding

In Super Admin → Settings → Shared Dify workspace, enable the shared connection and enter
its base URL (without `/v1`), Knowledge API key, embedding provider/model, and reranking
provider/model once. All accounts, including newly created accounts, inherit these settings.
Each assistant still provisions its own FAQ and document datasets. Shopify catalogs keep
separate datasets selected through server-owned tenant bindings. Customer APIs and model
output cannot choose dataset IDs or read the workspace credential.

The key is encrypted using Active Record encryption. Its knowledge-service copy is encrypted
at rest using a domain-separated key derived from `CWAI_SIGNING_KEY`. The saved key never
appears in forms. Leaving the key field blank preserves it. When rotating the signing key,
re-save the shared workspace before resuming the knowledge API and worker.

Deploy both migrations (Rails and knowledge-service Alembic), and update the knowledge API
and worker before enabling the setting. `CWAI_DEFAULT_CONNECTION_REF` selects the existing
server connection to replace centrally (default `prod`; the lab example uses `lab`). Enabling the shared workspace rejects active bindings for other credential references;
migrate those bindings explicitly first. Only a signed installation
configuration token can update this connection; tenant read/write tokens cannot.

The knowledge API registers an unseen account lazily on its first authenticated request.
It does not re-enable an explicitly disabled binding. Configuration writes update API and
worker behavior without a process restart. When Shopify tools have an admin credential
configured, the same save updates their platform Dify defaults and preserves chunking settings.
Existing catalog dataset connections are not rewritten by this operation.

Reranking changes affect subsequent Captain searches across FAQ, document, and catalog
knowledge. Embedding changes affect new datasets. Existing dataset indexes are never rebuilt
implicitly; migrate them explicitly after retrieval quality checks. Disabling the shared
setting restores legacy account settings and server connection configuration; it stops new
automatic account bindings and does not delete existing datasets or bindings.

Configuration propagation spans independent services. If a save fails after a remote service
accepts it, the form reports failure; retry the same save to reconcile all services. Keep the
connection in the same Dify workspace when updating a URL or rotating a key. Moving to a
different workspace requires a separate dataset migration.

Before the shared connection is enabled, legacy per-account configuration remains available
in Super Admin → Accounts. These settings are excluded from client account APIs.

New assistants in configured accounts enqueue dataset provisioning. Existing assistants
provision on first use of `ensure_dify_datasets!`. A lock prevents concurrent creation;
each dataset ID is persisted separately so a second-dataset failure preserves the first.
The IDs live in assistant config and are omitted from the client assistant response.

The reusable `Dify::KnowledgeClient` supports dataset creation/read, text/file document
creation, text updates, deletion, indexing status and retrieval. It accepts Dify's
`retrieval_model` for hybrid search, reranking and metadata conditions. Safe reads/deletes
have bounded retries; mutating POSTs are not retried because Dify lacks idempotency keys.
Errors contain status codes, never response bodies or credentials.

Dify sets parent-child chunking on the first document write using
`doc_form: "hierarchical_model"` and hierarchical processing rules. Empty datasets do not
accept a chunking mode through the dataset-create API. The Documents ingestion task must
supply that configuration; FAQ ingestion must keep one unsplit document per FAQ.

Platform admins can attach extra datasets from the Rails console:

```ruby
assistant = Captain::Assistant.find(assistant_id)
assistant.dify_extra_dataset_ids = approved_dataset_ids
assistant.save!
```

The setter verifies every dataset through the account's workspace key before persisting.
Client APIs never permit any of the Dify dataset IDs. Retrieval callers obtain the dataset
list from `assistant.dify_dataset_ids`, never from model output or browser parameters.

Before a lab release, verify that the installed Dify version supports the configured
embedding provider and the required hybrid, reranking and metadata retrieval options.
Use synthetic documents for acceptance checks and keep private configuration in lab records.

## FAQ ingestion

Captain FAQ saves enqueue a Dify sync instead of an embedding job. Configure the account's
Dify workspace first; unconfigured accounts do not enqueue knowledge writes. FAQ suggestion
saves no longer enqueue embeddings either. Duplicate search is replaced in the search task.

Each FAQ has an indexed `dify_document_id`. The sync creates a short, single-chunk placeholder
document, persists its ID, and waits for indexing through bounded job retries. Dify's native
segment API replaces that chunk with `question: …` and `answer: …` on separate lines. The full
FAQ never goes through Dify's text splitter or cleaning rules. Edits update the same chunk;
deletes remove the document. Moving an FAQ to another assistant deletes its old document and
creates one in the destination dataset. Dataset IDs come from the assistant's server records.

Retries recover document creation by its stable FAQ ID name if a response was lost, skip
unchanged completed chunks, and log exhausted failures by FAQ ID and HTTP status without
private content. A document with an unexpected chunk count fails explicitly.

Backfill existing FAQs for a configured assistant:

```sh
bundle exec rake captain:dify:backfill_faqs ASSISTANT_ID=123
```

The task can be run again safely: it reuses document IDs and updates only changed or failed
chunks. It does not alter the question or answer in Captain. Native search remains in place
until the separate search replacement task is released.

## Documents and PDFs

In configured accounts, parsed website and markdown content goes to the assistant's
Documents dataset with parent-child chunking. Captain stays in progress while Dify indexes;
polling marks it Ready only when the current content is completed and enabled. A fingerprint
prevents an older poll from marking a newer edit Ready. Exhausted retries and indexing errors
set a failed sync status with a safe error code. Metadata holds the Dify document ID,
indexing state and the submitted fingerprint.

PDF processing enqueues a direct multipart upload to Dify and never initializes an OpenAI
client. Dify extracts the PDF text; PDF FAQ generation is disabled. A missing workspace
configuration fails explicitly. Website and markdown FAQ generation continues after indexing.
Periodic website sync updates the existing Dify document; unchanged completed documents are
reused. Deletion removes the Dify document and its Captain-generated FAQs.

Backfill existing documents for one configured assistant:

```sh
bundle exec rake captain:dify:backfill_documents ASSISTANT_ID=123
```

Repeated runs reuse document IDs and fingerprints. An interrupted create is recovered by
its stable document name and resubmitted with current content before becoming Ready.

## Voyage 4 Lite evaluation — 2026-10-10

A read-only production comparison sent five representative question embeddings through
LiteLLM, alternating model order. Both models returned 1024-dimensional vectors.

| Model | Median | Mean | Samples |
| --- | --- | --- | --- |
| Voyage 4 | 0.299 s | 1.043 s | 5 |
| Voyage 4 Lite | 0.395 s | 0.494 s | 5 |

One Voyage 4 request took 4.020 s. These small samples do not establish a reliable median
latency improvement for Lite.

A separate process used Lite query embeddings against the existing Voyage 4 FAQ, document,
and catalog vectors. No dataset model or index was changed. Across three questions and three
datasets, the top vector-search result matched in 8/9 comparisons. Top-six overlap ranged
from 3/6 to 6/6. This measures agreement, not correctness. Queries after the first dataset
benefited from Dify's embedding cache; their timings are not cold model latency measurements.

Voyage documents compatible embedding spaces across its 4 family, with matching dimensions
and encoding. Prefer testing a separate query-model selection while keeping the existing
document embeddings. The deployed Dify Vector implementation currently selects the dataset's
embedding model for queries; separate query-model support is not included in this change.
See https://blog.voyageai.com/2026/01/15/voyage-4/.

Retrieval requests are capped at four results per dataset, preserving smaller caller limits.
The assistant still accepts up to five passages across all datasets. Production uses
`voyage/rerank-3-lite`; all FAQ, document, and catalog datasets remain searchable.
