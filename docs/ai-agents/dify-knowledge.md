# Dify workspace binding

In Super Admin → Accounts, configure the Dify base URL (without `/v1`), workspace Knowledge
API key, embedding provider and embedding model. Use one workspace per account and the same
embedding model as its catalog. Configure the installation's Active Record encryption keys
before storing a Knowledge API key. The form never displays a saved key; leaving it blank
keeps the current value. These settings are excluded from client account APIs.

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
