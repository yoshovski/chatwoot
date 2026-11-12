# Starts the payment for one pack of extra AI conversations (T07). It never credits: Enterprise::Billing::TopUpEventService
# does that from the webhook. With a saved card the pack is an invoice charged at once; without one, a Checkout page
# that also saves the card for the next pack and for auto top-up.
class Enterprise::Billing::TopUpService
  class Unavailable < StandardError; end
  class PaymentFailed < StandardError; end

  REQUEST_ID = /\A[\w-]{8,64}\z/

  def initialize(account:)
    @account = account
  end

  # request_id comes from the page, one per click, so a double submit or a retried request charges once.
  def buy(request_id: nil)
    subscription = @account.account_subscription
    raise Unavailable unless subscription&.top_up_available?

    key = "top-up-#{@account.id}-#{REQUEST_ID.match?(request_id.to_s) ? request_id : SecureRandom.uuid}"
    payment_method = saved_payment_method(subscription)
    return checkout(subscription, key) unless payment_method

    charge(subscription, payment_method, key, auto: false)
  end

  # Run by AutoTopUpJob. The ceiling and the in-flight mark are taken under the account lock; Stripe is called outside it
  # so AI replies (which take the same lock) do not wait for the payment.
  def auto
    subscription = nil
    step = @account.with_lock do
      subscription = @account.account_subscription&.reload
      subscription.start_auto_top_up! if subscription&.auto_top_up_due?
    end
    return unless step

    payment_method = saved_payment_method(subscription)
    return subscription.auto_top_up_failed! unless payment_method

    charge(subscription, payment_method, "auto-top-up-#{@account.id}-#{step}", auto: true)
  rescue PaymentFailed, Stripe::StripeError => e
    Rails.logger.warn("Auto top-up failed for account #{@account.id}: #{e.message}")
    nil
  end

  private

  def charge(subscription, payment_method, key, auto:)
    invoice = create_invoice(subscription, payment_method, key, auto)
    if invoice.status == 'draft'
      invoice = Stripe::Invoice.finalize_invoice(invoice.id, { auto_advance: false }, { idempotency_key: "#{key}-finalize" })
    end
    invoice = Stripe::Invoice.pay(invoice.id, { off_session: true }, { idempotency_key: "#{key}-pay" }) if invoice.status == 'open'
    { status: invoice.status == 'paid' ? 'paid' : 'processing' }
  rescue Stripe::CardError => e
    payment_failed(subscription, invoice, e, auto)
  end

  # The card needs the customer (3-D Secure): someone clicking can confirm on Stripe's invoice page, which pays the same
  # invoice, so the webhook credits it. An automatic payment has no one to confirm it, so it fails like a declined card.
  def payment_failed(subscription, invoice, error, auto)
    if !auto && error.code == 'authentication_required' && invoice
      return { status: 'action_required', url: Stripe::Invoice.retrieve(invoice.id).hosted_invoice_url }
    end

    Stripe::Invoice.void_invoice(invoice.id) if invoice
    subscription.auto_top_up_failed! if auto
    raise PaymentFailed, error.message
  end

  def create_invoice(subscription, payment_method, key, auto)
    invoice = Stripe::Invoice.create(
      { customer: subscription.stripe_customer_id, currency: subscription.currency, collection_method: 'charge_automatically',
        auto_advance: false, default_payment_method: payment_method, pending_invoice_items_behavior: 'exclude',
        automatic_tax: { enabled: true }, description: pack_name, metadata: metadata(auto: auto) },
      { idempotency_key: "#{key}-invoice" }
    )
    return invoice unless invoice.status == 'draft'

    Stripe::InvoiceItem.create(
      { customer: subscription.stripe_customer_id, invoice: invoice.id, currency: subscription.currency,
        amount: AccountSubscription::PACK_PRICE_CENTS, tax_behavior: 'exclusive', description: pack_name },
      { idempotency_key: "#{key}-item" }
    )
    invoice
  end

  # invoice_creation gives the customer a real invoice with VAT; its metadata lets the webhook credit it by invoice id,
  # the same key checkout.session.completed uses.
  def checkout(subscription, key)
    session = Stripe::Checkout::Session.create(
      { customer: subscription.stripe_customer_id, mode: 'payment',
        line_items: [{ price_data: { currency: subscription.currency, unit_amount: AccountSubscription::PACK_PRICE_CENTS,
                                     tax_behavior: 'exclusive', product_data: { name: pack_name } }, quantity: 1 }],
        automatic_tax: { enabled: true }, tax_id_collection: { enabled: true }, billing_address_collection: 'required',
        customer_update: { address: 'auto', name: 'auto' },
        invoice_creation: { enabled: true, invoice_data: { description: pack_name, metadata: metadata(auto: false) } },
        payment_intent_data: { setup_future_usage: 'off_session' },
        metadata: metadata(auto: false), success_url: return_url, cancel_url: return_url },
      { idempotency_key: "#{key}-checkout" }
    )
    { status: 'checkout', url: session.url }
  end

  # The card the subscription pays with, else the customer's default, else any card saved on the customer.
  def saved_payment_method(subscription)
    remote = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)
    customer = Stripe::Customer.retrieve(subscription.stripe_customer_id)
    id_of(remote['default_payment_method']) || id_of(customer.invoice_settings&.default_payment_method) ||
      Stripe::PaymentMethod.list(customer: subscription.stripe_customer_id, limit: 1).data.first&.id
  end

  def id_of(value)
    value.is_a?(String) ? value : value&.id
  end

  def metadata(auto:)
    { chatoctave_top_up: AccountSubscription::PACK_CONVERSATIONS.to_s,
      chatoctave_account_id: @account.id.to_s, auto_top_up: auto.to_s }
  end

  def pack_name
    I18n.t('account_subscription.top_up.pack_name', count: AccountSubscription::PACK_CONVERSATIONS)
  end

  def return_url
    "#{ENV.fetch('FRONTEND_URL').chomp('/')}/app/accounts/#{@account.id}/settings/billing"
  end
end
