# ChatOctave account controls, exports and billing

## Rollout

Run `bundle exec rails db:migrate` before starting the new app and Sidekiq workers. Existing accounts retain unrestricted service until an operator configures a trial. Conversation tracking starts with this release; historical messages are not backfilled. No Shopify Agent Tools changes are required.

Super Admin → Accounts → Edit → Features exposes **Calls dashboard** and **Octave AI overview summary**, both disabled by default. Calls requires Enterprise. The summary toggle controls both overview versions and their generation endpoints.

## Branding

Set Installation Name to ChatOctave, Logo to the desired login logo, and Logo Thumbnail to the desired favicon in Super Admin. A custom Logo is also used in dark mode when Logo Dark Mode still uses the bundled default; an explicitly customized dark logo takes precedence. Dashboard/login favicon and Apple touch icon use Logo Thumbnail without competing bundled favicons. Reload the login page after saving branding.

## Account billing

Super Admin → Accounts → Edit → Subscription settings configures the account's monthly conversation limit, trial, monthly price, yearly discount, optional custom yearly price, currency, one-time setup fee and billing period dates. Supported currencies are EUR, USD, GBP and BRL. Prices use minor units (cents/pence); dates are UTC. Blank monthly limits are unlimited; zero permits no new trial conversations.

A billable conversation starts with a public incoming message. More messages in the same conversation during the next **24 hours** do not add usage. The first incoming message after that fixed window starts a new billable window; this is not a sliding inactivity timer. Private notes and activity messages do not count. Reopening does not reset the window. Deleting messages or conversations preserves aggregate usage.

Quotas reset monthly from the account's quota anchor, including yearly subscribers. Month-end anchors clamp to the last valid day of shorter months without drifting in subsequent months. **Refresh monthly quota now** starts a new monthly quota while retaining previous periods in usage history. Previously admitted 24-hour windows can finish without being billed twice across a monthly boundary.

Trials pause new AI conversations when the quota is reached; already admitted windows can finish until the trial expires. Trial expiry pauses all AI replies. Incoming messages and human agents remain available. Paid and manually managed clients remain operational above quota, with a warning starting at 80%. Neither missed payments nor period end suspend paid-client conversations under the current policy.

Turning on a trial initializes its expiry from Trial duration if the expiry field is blank. To restart or extend a trial, set its expiry explicitly or clear the expiry and save. Disabling a trial removes trial enforcement. A paid Stripe subscription automatically clears trial enforcement. A canceled/unpaid trial retains its expiry and restriction.

Accounts see consumption, quota reset, billing period and recent usage history under **Settings → Billing**, plus a compact sidebar panel. Administrators can subscribe monthly/yearly, manage payments and pay a specific customization request. Yearly price is custom yearly price when supplied, otherwise `monthly price × 12 × (100 − yearly discount) / 100`, rounded to cents.

## Stripe setup and client-specific payments

Use `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` and the public `FRONTEND_URL`. Start with test-mode credentials. Register `/enterprise/webhooks/stripe` for:

- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`

Enable the Stripe customer portal for invoices and payment methods. Checkout always uses the server's saved account price; customers cannot submit a price or another account's identity. The configured setup fee is a one-time line on a new subscription. Buying with fewer than 48 hours left in a trial starts the paid subscription immediately; longer remaining trials keep their configured expiry.

For a separate customization invoice/payment, set **Custom one-time payment** and its description. The account's administrator sees a payment button. A verified paid checkout clears that pending request. Changing its amount/description/currency or selecting **Issue a new payment request** creates a new request; repeated delivery of the payment webhook does not fulfill it twice. These payments do not change the subscription or quota.

After changing an existing client's recurring price, use **Apply saved pricing to Stripe** on the Super Admin account detail page. The new price applies to future renewals without an immediate prorated invoice. Changing currency for an active Stripe subscription is subject to Stripe restrictions. For manually billed clients, date edits are immediate. To defer an existing Stripe renewal, save the new billing end date and use **Extend Stripe renewal**; the date must be more than 48 hours ahead. This payment deferral does not turn a paid client into a quota-enforced trial. Stripe remains authoritative for synced payment period dates.

Subscription events read current Stripe state to resist replay and reordered delivery. Account/customer matching is required. Existing cloud/Shopify billing APIs continue to operate independently; this account-pricing flow uses a dedicated Stripe customer and does not cancel existing legacy subscriptions. Do not migrate a currently subscribed legacy client without first coordinating cancellation to avoid overlapping subscriptions.

## Data exports

Account administrators use **Settings → Data exports** to request conversations, contacts, knowledge or all three. A Sidekiq job prepares a `.tar.gz` archive with a versioned manifest and JSON Lines records. Conversation archives include messages and attachment originals. Knowledge archives include help-center articles, customer-visible Octave documents/FAQs and uploaded originals. Native knowledge library bases use their portable ZIP export, including authored sources and revisions.

The Shopify synchronization service and its product catalog are never queried for exports. Account/integration credentials, assistant configuration/prompts, embedding indexes and internal strategy settings are excluded; agents-only Octave documents/FAQs are excluded. Conversation private notes remain part of the conversation archive.

Only one export per account may be queued/preparing at a time. Archives are available for seven days, downloaded through an authenticated account/admin endpoint, and purged by a scheduled cleanup job. There are no public archive links. Keep the low-priority Sidekiq queue running. Generation checks that its requester is still an account administrator; failed jobs show a retry state without disclosing content or provider errors. If a worker dies during preparation, an operator should mark its stale export failed before retrying.

## Verification

Use Stripe test mode to check monthly and yearly checkout, trial transition, customization payment, renewal date extension and payment-method management. Confirm a forged webhook is rejected and repeating a valid event does not reset usage. Confirm two messages in one conversation within 24 hours consume one unit, a later window consumes another, paid accounts continue beyond quota, trial expiry blocks bot replies, and another account cannot download an export.

Validated locally on the isolated billing branch: 218 existing Ruby examples and four frontend checks passed; the frontend build passed with a 6 GiB Node heap. Runtime checks verified quota accounting, archive generation/authenticated downloads, cross-account denial and mocked Stripe flows. Live Stripe checkout and the deployed installation's configured assets still require rollout verification.
