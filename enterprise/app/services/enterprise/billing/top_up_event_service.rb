# Credits packs of extra AI conversations from Stripe events (T07). The ledger key is the pack's invoice id, which both
# invoice.paid and checkout.session.completed carry, so the same payment credits once however many events arrive.
# Top-up invoices never touch the subscription's own payment facts: a paid pack must not clear a failed renewal.
class Enterprise::Billing::TopUpEventService
  METADATA_KEY = 'chatoctave_top_up'.freeze
  INVOICE_EVENTS = %w[invoice.paid invoice.payment_failed invoice.payment_action_required invoice.finalized invoice.voided
                      invoice.marked_uncollectible invoice.upcoming].freeze
  CHECKOUT_EVENTS = %w[checkout.session.completed checkout.session.async_payment_succeeded checkout.session.expired
                       checkout.session.async_payment_failed].freeze
  CREDIT_EVENTS = %w[invoice.paid checkout.session.completed checkout.session.async_payment_succeeded].freeze
  FAILURE_EVENTS = %w[invoice.payment_failed invoice.payment_action_required].freeze

  # True when the event is about a pack (handled here, nothing else should run for it).
  def self.handle(event)
    new(event).handle
  end

  def initialize(event)
    @event = event
    @object = event.data.object
  end

  def handle
    return false unless top_up?
    return true unless subscription && metadata['chatoctave_account_id'] == subscription.account_id.to_s

    credit if CREDIT_EVENTS.include?(@event.type)
    automatic_payment_failed if FAILURE_EVENTS.include?(@event.type) && metadata['auto_top_up'] == 'true'
    true
  end

  private

  def top_up?
    (INVOICE_EVENTS + CHECKOUT_EVENTS).include?(@event.type) && metadata[METADATA_KEY].present?
  end

  # Re-read Stripe so a replayed or forged-looking event credits only what is actually paid.
  def credit
    invoice_id, conversations = paid_pack
    return unless invoice_id

    account = subscription.account
    account.with_lock do
      ExtraAiConversationEntry.credit!(account: account, amount: conversations, stripe_reference: invoice_id)
      subscription.reload.update!(auto_top_up_pending_at: nil) if metadata['auto_top_up'] == 'true'
    end
  end

  def paid_pack
    if @object['object'] == 'checkout.session'
      session = Stripe::Checkout::Session.retrieve(@object['id'])
      return unless session.payment_status == 'paid'

      [session.invoice.presence || session.id, conversations_from(session.metadata)]
    else
      invoice = Stripe::Invoice.retrieve(@object['id'])
      return unless invoice.status == 'paid'

      [invoice.id, conversations_from(invoice.metadata)]
    end
  end

  def conversations_from(remote_metadata)
    count = remote_metadata.to_h.stringify_keys[METADATA_KEY].to_i
    count.positive? ? count : AccountSubscription::PACK_CONVERSATIONS
  end

  # A declined card or one that needs the customer, after the request that started it (an async method, or Stripe's
  # own retry). The request path already switched auto top-up off for a synchronous decline; this keeps the first time.
  def automatic_payment_failed
    subscription.account.with_lock do
      subscription.reload
      subscription.auto_top_up_failed! if subscription.auto_top_up_enabled? || subscription.auto_top_up_pending_at
    end
  end

  def metadata
    @metadata ||= @object['metadata'].to_h.stringify_keys
  end

  def subscription
    return if @object['customer'].blank?

    @subscription ||= AccountSubscription.find_by(stripe_customer_id: @object['customer'])
  end
end
