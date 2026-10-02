# Canonical AI knowledge foundation (CWAI-2)

This independent Python 3.12 service owns canonical knowledge and projects it to
Dify's server-side Knowledge API. Rails retains users, membership and AgentBot
identity. Captain and existing bot routing are unchanged. The service and the
account feature `native_ai_knowledge` are disabled by default.

## Data and authority

An administrator provisions `AccountBinding` using the CLI. Its installation and
Chatwoot account select a server-configured Dify credential reference. Neither the
browser nor the model can select credentials, tenant IDs or remote index IDs.
Rebinding an existing account to a different credential reference requires an
explicit index migration; the provisioning CLI refuses that change.

Knowledge bases, sources, entries, agents, attachments, projections and jobs are
account-owned. Compound foreign keys enforce account/base ownership. Immutable
source and entry revisions retain exact text, actor and provenance. Source files
are private files keyed by generated IDs, with SHA-256 recorded in each revision.
Editing extracted text retains the previous original unless new bytes are supplied.
Manual question/answer text is never trimmed, regenerated or replaced by Dify output.

Every edit/state change queues a persisted indexing job in the same PostgreSQL
transaction. Workers serialize each projection with transaction advisory locks,
which release after a crash. Stable dataset/document names recover accepted POSTs
whose acknowledgements were lost. Readiness requires confirmed completion and
remote segment mappings. Errors use safe codes, exponential backoff and at most
eight attempts; failed jobs can be explicitly retried. An index stalled for 30
minutes fails and can be retried. Missing datasets/documents rebuild from canonical
records. Rebuilds advance the projection epoch and preserve revisions and enabled
state. No in-memory background tasks are used.

FAQ and contextual sources have separate physical indexes. Retrieval accepts only
remote IDs mapped to current, ready, enabled canonical revisions. Disabled bases,
entries and source-derived FAQs are filtered locally before asynchronous remote
cleanup. Returned FAQ text comes from the canonical revision. Citation validation
rechecks that gate; remote scores are ranking values, not confidence percentages.
The later reply delivery gate must revalidate citations immediately before sending.
This foundation does not yet implement conversation delivery or agent execution.

## API integration

Rails exposes `/api/v1/accounts/:account_id/ai_agents/knowledge/*`. Existing Rails
authentication enforces membership. Members can read/retrieve; only account
administrators can mutate. The feature flag must be enabled. Account-owned bot IDs
are verified before creating the service's minimal agent record. Full agent
configuration/versioning remains a later task.

The proxy signs a 60-second HS256 credential containing installation issuer,
audience, account, actor and a read/write action. The service derives its tenant
from that signed account binding. Public responses omit remote IDs and credential
references. Unknown request fields and invalid shapes are rejected. Source bytes
are downloaded through authenticated endpoints, never public file URLs.

The service API is `/v1/knowledge`; its authenticated schemas are visible in
`/docs`. It supports base creation/state, attachments, source/entry revisions,
optimistic edits (`expected_version`), review/state changes, rebuild, job status and
retry, retrieval and citation validation. The service is private infrastructure;
expose the Rails proxy to users. The native Knowledge library lives at
`/app/accounts/:account_id/knowledge`, independently of Captain and edition.
Its sidebar and API remain hidden/denied unless `native_ai_knowledge` is enabled.

## Isolated lab setup

Copy `.env.example` to `.env` and configure a private PostgreSQL database, a random
signing secret, an installation ID, private originals path and **lab-only** Dify
Knowledge credentials/model configuration. Credentials stay in `.env` or your
secret manager. Use synthetic data and service-owned datasets. No existing Dify
datasets or commerce indexes are imported or modified.

For Compose, set `CWAI_DB_PASSWORD` and use the matching password with hostname
`ai-db` in `CWAI_DATABASE_URL`. Configure the lab Dify endpoint reachable from the
Compose network. API and worker share the originals volume; PostgreSQL has its own
volume. The API binds to loopback by default.

```sh
docker compose up --build -d ai-db migrate api
docker compose run --rm api cwai 123 --credential-ref lab --enable
```

Set `CWAI_ENABLED=true` explicitly for the service before starting the indexing
profile:

```sh
docker compose --profile indexing up --build -d
```

Configure Rails `CWAI_SERVICE_URL`, `CWAI_INSTALLATION_ID` and the same
`CWAI_SIGNING_KEY`, then enable `native_ai_knowledge` on the isolated lab account.
Do not enable production accounts or alter live n8n/Dify/Shopify routing.

For development without containers:

```sh
uv sync --frozen --extra dev
uv run --frozen alembic upgrade head
uv run --frozen alembic check
uv run --frozen uvicorn cwai.api:app --port 8010 --no-access-log
uv run --frozen cwai-worker
```

## Validation and recovery

`validation/run.py` requires `CWAI_VALIDATION_ALLOW=true` and a disposable database.
`fixture` mode uses `validation/dify_fixture.py` with `fixture-a`/`fixture-b`
connections and injects lost acknowledgements, failures and worker termination.
`live` mode uses the first configured lab connection and creates new synthetic
accounts/datasets. These scripts leave synthetic canonical records/indexes for
inspection; reset the disposable database and remove only its owned datasets when
finished. The fixture is validation-only and excluded from the runtime image.

`validation/rails_proxy.rb` runs with `rails runner` in a disposable lab process
containing the new Rails files. Set `CWAI_VALIDATION_ACCOUNT_A/B` to the two service
accounts created by a fixture run. The process must reach that service with matching
signing configuration. It checks membership, role, feature flag, foreign bot and
parameter rejection plus actual signed proxy reads. Its synthetic Rails records
are rolled back. Use the existing lab image with file overlays rather than
replacing the running lab application for this narrow validation.

CI runs frozen dependency installation, Ruff lint/format, PostgreSQL migrations and
metadata drift detection, the fault-injection acceptance run and service image
build. Existing Rails/frontend checks remain enabled.

Back up PostgreSQL, originals and private connection configuration together.
Migrations are independent of Chatwoot's Rails schema. Revision immutability is
enforced by PostgreSQL triggers. Downgrade deliberately refuses destructive
rollback: stop API/workers and restore the previous database and original-files
snapshot together when reverting a schema. Rebuilding Dify never changes the
canonical backups. A previous service image can use the unchanged initial schema;
the published Chatwoot v1 tag is not rewritten or replaced by this work.

## Native library and portability (CWAI-3)

Administrators create/rename/disable bases, add/edit/review/disable manual FAQs,
maintain source text and original files, and reuse bases across account-owned
agents. Members can browse, inspect immutable history, preview CSV and download
exports/originals. Disable takes effect at the canonical retrieval gate immediately;
indexing remains asynchronous. Failed indexing can be rebuilt from the base screen.
Source uploads retain original bytes; text extraction is a later phase. The library
never enumerates or imports integration-owned Shopify catalog indexes.

CSV endpoints under `/bases/{base_id}` are `POST csv/preview` (read scope),
`POST csv/import` (write scope), and `GET csv`. Upload JSON is `{ "csv": "..." }`.
UTF-8 (optional BOM), RFC-style quoted fields, exact multiline text and whitespace
are supported. Required columns: `question,answer`. Optional columns:
`id,version,enabled,review_state,source_id,source_revision_id,provenance`.
No unknown/duplicate headers or extra columns are accepted. Limits: 1,000 records
and 5 MiB per import; each question/answer is 1–100,000 characters. Preview never
writes. Import revalidates all rows inside one base-locked transaction; any invalid
row rejects the entire import. IDs cannot refer to another account/base. Existing
IDs require the current exported version; unchanged rows create no revisions/jobs.
New UUIDs and exported versions are retained. Boolean values are exactly
`true`/`false`; review values are `approved`/`draft`; provenance is a JSON object.
Source ID and immutable source revision must both belong to this base. Omitted
state/provenance columns use documented create defaults (enabled, approved, `{}`),
so use the complete exported header when editing existing records. Large exports
can be partitioned into import batches retaining the header. Treat canonical CSV
as text when opening in spreadsheets to preserve wording and avoid formula coercion.

`GET /bases/{base_id}/export` downloads a ZIP containing `manifest.json`,
`faqs.csv`, and deduplicated `originals/{source_id}/{sha256}.bin` files. Manifest
schema version 1 contains base metadata, all entries/sources and immutable revision
history (including actor, provenance, exact text, original filenames/media types
and checksums). Original paths inside the archive are generated, never user paths.
It excludes tenant bindings, filesystem storage keys, signing/Dify credentials,
remote dataset/document/segment mappings and indexing jobs. User-authored provenance
is preserved as supplied. Export takes a consistent base-locked snapshot and is
bounded to 100 MiB of uncompressed canonical data/originals. ZIP restoration is not
an API in this phase; CSV supports FAQ exchange, while the ZIP preserves the full
canonical content for future restore/migration tooling.
