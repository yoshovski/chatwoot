# Usage & billing review — 2026-10-13

## Findings and decisions

| Finding                                                                                                                                                   | Impact                                                                             | Change                                                                                                                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| “Account plan” does not say whether a subscription exists; the purchase selector can be shown when Stripe has a subscription that was not linked locally. | High: customers may attempt to subscribe twice.                                    | Recover the customer subscription on page entry and recheck before checkout. Show explicit lifecycle status; existing subscriptions have management actions only.                          |
| Saved monthly/yearly offer prices can differ from the subscription actually charged.                                                                      | High: misleading billing information after an operator edits future offer pricing. | Store and display Stripe's subscription item amount, currency, quantity and interval. Unknown existing pricing is explicitly unavailable, never replaced with an offer.                    |
| “Active” can be mistaken for confirmation that every invoice is paid.                                                                                     | High: payment obligations are unclear.                                             | Show subscription status and latest invoice status separately. Show “Paid” only for a paid invoice.                                                                                        |
| Scheduled cancellation, overdue, unpaid, incomplete, expired and paused states lack clear next actions.                                                   | High: customers cannot tell whether to pay, renew or subscribe.                    | Explain every state, distinguish scheduled end from renewal, and direct payment problems to invoices/payment management. Payment problems remain visible alongside scheduled cancellation. |
| Repeated or interval-switched checkouts can create multiple open sessions.                                                                                | High: overlapping checkout links can produce duplicate subscriptions.              | Persist the pending session, reuse it for the same interval, expire it before switching interval, and reject completed sessions pending subscription reconciliation.                       |
| An interpolated line chart and a minimum 100-unit chart scale obscure small exact usage totals and require horizontal scrolling on narrow screens.        | Medium: history is hard to read and implies continuity between discrete periods.   | Replace it with a semantic, exact period-total table. Explicitly distinguish the current partial period from completed periods.                                                            |
| Billing period progress competes visually with conversation quota progress.                                                                               | Medium: customers can confuse a time bar with consumption.                         | Retain the conversation allowance bar; present subscription dates as labeled facts. Monthly quota reset stays separate from yearly renewal.                                                |
| Billing controls contain price data even though agent-role responses intentionally contain usage only.                                                    | Medium: confusing role-specific presentation.                                      | Render subscription and plan sections only for administrators. Non-administrator API responses remain usage-only; the Billing route itself remains administrator-only.                                                              |

## Behavior

- Existing subscription: current recurring price, cadence, status, renewal/end date, billing period, latest invoice and management action. No checkout selector or “Continue” button.
- No online subscription: explicit absence, a note for separately billed accounts, monthly/yearly offers and an explicit “Subscribe” action. This page does not invent a paid status for manually managed accounts.
- Ended/expired subscription: explain its state and offer a new subscription only when eligible.
- Deferred paid renewal: label the operator-granted payment extension explicitly, rather than calling it a free trial. Ended subscriptions use Stripe's actual end timestamp when available.
- Payment issue: explain the problem and emphasize invoice/payment management. Paid-client reply behavior and trial quota policy remain governed by the existing service rules.
- Payment-provider refresh failure: keep saved details visible with an explicit warning and retry. Hide new checkout until verification succeeds; checkout also checks the provider on the server.
- Customer portal: manage the subscription, payment methods and invoices. Custom inline Checkout prices do not automatically support portal interval switching; contact the account team for a frequency change. Configure portal cancellation/payment features for the installation.
- Responsive presentation: wrap labels/dates and use a single-column offer selector on narrow screens. Native radio controls, focus rings, semantic definition lists/history table and alert text provide keyboard/screen-reader support.

## Source-of-truth rules

Stripe is authoritative for the existing subscription and latest invoice. The saved account offer controls new checkout pricing. Invoice totals may differ from recurring item prices due to taxes, discounts, credits and one-time charges. Conversation allowance counts 24-hour conversation windows rather than tokens or model spend. Tenant cost attribution is described in [LiteLLM tenant usage](ai-agents/litellm-tenant-usage.md).

Primary references:

- [Stripe subscription lifecycle](https://docs.stripe.com/billing/subscriptions/overview): distinguish active/trial/payment-failure/end states.
- [Stripe subscription integration](https://docs.stripe.com/billing/subscriptions/build-subscriptions?payment-ui=checkout&ui=stripe-hosted): use webhooks and customer portal management for existing subscribers.
- [Stripe invoice lifecycle](https://docs.stripe.com/invoicing/integration/workflow-transitions): distinguish draft, open, paid, void and uncollectible invoices.

## Rollout and validation

Run the database migration before application/workers. Add the invoice webhook types listed in [account billing](chatoctave-account-billing.md). Existing customers are reconciled when an administrator opens Billing or attempts checkout; ordinary usage polling reads local webhook state. Review deployed Stripe portal settings and perform monthly/yearly test-mode checkout, failure recovery, cancellation and checkout return after deployment. Local fixtures do not establish that production invoices are paid or that deployed gateway tracking is complete.

Local validation: 230 existing Ruby examples, 15 subscription-component scenarios, fixture-based Stripe reconciliation/checkout checks and two-tenant chat/embedding header checks passed. Ruby lint and targeted frontend lint had no errors; the production Vite build passed. Browser review used the actual subscription component with local fixtures at desktop and narrow widths. Live payments and Dify attribution remain rollout checks.
