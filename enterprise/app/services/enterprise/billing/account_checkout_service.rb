class Enterprise::Billing::AccountCheckoutService
  class Unavailable < StandardError; end

  def initialize(account:)
    @account = account
  end

  def checkout(interval:)
    @account.with_lock do
      Enterprise::Billing::AccountSubscriptionSyncService.refresh(@account)
      subscription = @account.subscription_settings
      subscription.reload if subscription.persisted?
      validate_checkout(subscription)
      ensure_customer(subscription)
      pending = pending_checkout(subscription, interval)
      return { url: pending.url } if pending

      session = Stripe::Checkout::Session.create(
        checkout_parameters(subscription, interval),
        { idempotency_key: checkout_key(subscription, interval) }
      )
      subscription.update!(stripe_checkout_session_id: session.id)
      { url: session.url }
    end
  end

  def payment
    @account.with_lock do
      subscription = @account.subscription_settings
      raise Unavailable unless subscription.enabled? && subscription.custom_payment_cents.positive? && subscription.custom_payment_paid_at.blank?

      ensure_customer(subscription)
      session = Stripe::Checkout::Session.create(
        { customer: subscription.stripe_customer_id, mode: 'payment', success_url: return_url, cancel_url: return_url,
          metadata: { chatoctave_payment_revision: subscription.custom_payment_revision },
          line_items: [{ price_data: { currency: subscription.currency, unit_amount: subscription.custom_payment_cents,
                                       product_data: { name: subscription.custom_payment_description.presence || @account.name } }, quantity: 1 }] },
        { idempotency_key: "account-payment-#{subscription.id}-#{subscription.custom_payment_revision}-#{Time.current.to_i / 1800}" }
      )
      { url: session.url }
    end
  end

  def extend_period
    @account.with_lock do
      subscription = @account.account_subscription
      raise Unavailable if subscription&.stripe_subscription_id.blank?
      raise Unavailable unless subscription.period_ends_at && subscription.period_ends_at > 48.hours.from_now

      Stripe::Subscription.update(subscription.stripe_subscription_id,
                                  trial_end: subscription.period_ends_at.to_i, proration_behavior: 'none',
                                  metadata: { chatoctave_paid_extension: 'true' })
    end
  end

  def portal
    subscription = @account.account_subscription
    raise Unavailable if subscription&.stripe_customer_id.blank?

    { url: Stripe::BillingPortal::Session.create(customer: subscription.stripe_customer_id, return_url: return_url).url }
  end

  # Admin changes affect future renewals; no immediate proration invoice is generated.
  def apply_pricing
    @account.with_lock do
      subscription = @account.account_subscription
      raise Unavailable if subscription&.stripe_subscription_id.blank?

      remote = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)
      item = remote.items.data.first
      data = price_data(subscription, interval: subscription.billing_interval).except(:product_data)
      data[:product] = item.price.product
      Stripe::Subscription.update(remote.id, items: [{ id: item.id, price_data: data }], proration_behavior: 'none')
    end
  end

  private

  def validate_checkout(subscription)
    raise Unavailable unless subscription.checkout_available?

    subscription.save! if subscription.new_record?
  end

  def checkout_key(subscription, interval)
    ['account-checkout', subscription.id, interval, subscription.updated_at.to_i,
     subscription.stripe_checkout_session_id, Time.current.to_i / 1800].join('-')
  end

  def offer_signature(subscription)
    Digest::SHA256.hexdigest([subscription.currency, subscription.monthly_price_cents, subscription.annual_amount_cents,
                              subscription.setup_fee_cents, subscription.trial_active?, subscription.trial_ends_at].join(':'))
  end

  def pending_checkout(subscription, interval)
    return if subscription.stripe_checkout_session_id.blank?

    session = Stripe::Checkout::Session.retrieve(subscription.stripe_checkout_session_id)
    if session.status == 'complete'
      return if completed_checkout_ended?(subscription, session)

      raise Unavailable
    end
    return unless session.status == 'open'
    return session if session.metadata['billing_interval'] == interval && session.metadata['offer_signature'] == offer_signature(subscription)

    Stripe::Checkout::Session.expire(session.id)
    nil
  end

  def completed_checkout_ended?(subscription, session)
    session.subscription == subscription.stripe_subscription_id && %w[canceled incomplete_expired].include?(subscription.payment_status)
  end

  def checkout_parameters(subscription, interval)
    data = { metadata: { chatoctave_account_id: @account.id.to_s } }
    data[:trial_end] = subscription.trial_ends_at.to_i if subscription.trial_active? && subscription.trial_ends_at > 48.hours.from_now
    { customer: subscription.stripe_customer_id, mode: 'subscription', line_items: checkout_items(subscription, interval), subscription_data: data,
      metadata: { billing_interval: interval, offer_signature: offer_signature(subscription) },
      client_reference_id: @account.id.to_s, success_url: return_url, cancel_url: return_url }
  end

  def checkout_items(subscription, interval)
    items = [{ price_data: price_data(subscription, interval: interval), quantity: 1 }]
    return items unless subscription.setup_fee_cents.positive?

    items + [{ price_data: { currency: subscription.currency, unit_amount: subscription.setup_fee_cents,
                             product_data: { name: I18n.t('account_subscription.setup_fee') } }, quantity: 1 }]
  end

  def ensure_customer(subscription)
    return if subscription.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      { name: @account.name, metadata: { chatoctave_account_id: @account.id.to_s } },
      { idempotency_key: "chatoctave-customer-#{@account.id}" }
    )
    subscription.update!(stripe_customer_id: customer.id)
  end

  def price_data(subscription, interval:)
    { currency: subscription.currency, unit_amount: interval == 'year' ? subscription.annual_amount_cents : subscription.monthly_price_cents,
      recurring: { interval: interval }, product_data: { name: @account.name } }
  end

  def return_url
    "#{ENV.fetch('FRONTEND_URL').chomp('/')}/app/accounts/#{@account.id}/settings/billing"
  end
end
