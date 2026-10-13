class Enterprise::Billing::AccountSubscriptionSyncService
  EVENT_TYPES = %w[customer.subscription.created customer.subscription.updated customer.subscription.deleted].freeze
  INVOICE_EVENTS = %w[invoice.paid invoice.payment_failed invoice.finalized invoice.voided invoice.marked_uncollectible].freeze
  PAYMENT_EVENTS = %w[checkout.session.completed checkout.session.async_payment_succeeded].freeze

  def self.handle(event)
    service = new
    return service.sync_invoice(event.data.object) if INVOICE_EVENTS.include?(event.type)

    if PAYMENT_EVENTS.include?(event.type)
      return service.sync_invoice(event.data.object) if event.data.object['mode'] == 'subscription'

      return service.sync_payment(event.data.object)
    end
    return false unless EVENT_TYPES.include?(event.type)

    service.sync_subscription(event.data.object)
  end

  # Called on page entry and before checkout; webhooks remain the normal update path.
  def self.refresh(account)
    subscription = account.account_subscription
    return if subscription&.stripe_customer_id.blank?

    account.with_lock do
      subscription.reload
      service = new
      remote = service.remote_subscription(subscription)
      service.sync_remote(subscription, remote) if remote
      remote
    end
  end

  def remote_subscription(subscription)
    if subscription.stripe_subscription_id.present? && %w[canceled incomplete_expired].exclude?(subscription.payment_status)
      return Stripe::Subscription.retrieve(id: subscription.stripe_subscription_id, expand: ['latest_invoice'])
    end

    candidates = Stripe::Subscription.list(customer: subscription.stripe_customer_id, status: 'all', limit: 100)
                                     .auto_paging_each.select { |item| item.metadata['chatoctave_account_id'] == subscription.account_id.to_s }
    remote = candidates.max_by { |item| [%w[canceled incomplete_expired].exclude?(item.status) ? 1 : 0, item.created] }
    Stripe::Subscription.retrieve(id: remote.id, expand: ['latest_invoice']) if remote
  end

  def sync_remote(subscription, remote)
    return unless remote.customer == subscription.stripe_customer_id && remote.metadata['chatoctave_account_id'] == subscription.account_id.to_s
    return if older_subscription?(subscription, remote)

    attributes = subscription_attributes(subscription, remote)
    attributes[:quota_anchor] = attributes[:period_started_at] if subscription.stripe_subscription_id.blank?
    subscription.update!(attributes)
  end

  def sync_subscription(object)
    subscription = AccountSubscription.find_by(stripe_customer_id: object.customer)
    return false unless subscription
    return true unless object['metadata'].to_h[:chatoctave_account_id] == subscription.account_id.to_s

    subscription.account.with_lock do
      subscription.reload
      # Read authoritative state so replayed or reordered webhooks do not roll back entitlements.
      remote = Stripe::Subscription.retrieve(id: object.id, expand: ['latest_invoice'])
      sync_remote(subscription, remote)
    end
    true
  end

  def sync_invoice(object)
    subscription = AccountSubscription.find_by(stripe_customer_id: object.customer)
    return false unless subscription

    self.class.refresh(subscription.account)
    true
  end

  def sync_payment(object)
    subscription = AccountSubscription.find_by(stripe_customer_id: object.customer)
    return false unless subscription

    revision = object['metadata'].to_h[:chatoctave_payment_revision]
    return true unless revision == subscription.custom_payment_revision

    remote = Stripe::Checkout::Session.retrieve(object.id)
    return true unless remote.payment_status == 'paid'
    return true unless [remote.amount_total, remote.currency] == [subscription.custom_payment_cents, subscription.currency]

    subscription.with_lock do
      if subscription.custom_payment_revision == revision && subscription.custom_payment_paid_at.blank?
        subscription.update!(custom_payment_paid_at: Time.current)
      end
    end
    true
  end

  private

  def older_subscription?(subscription, remote)
    return false if subscription.stripe_subscription_id.blank? || subscription.stripe_subscription_id == remote.id

    subscription.stripe_subscription_created_at && Time.zone.at(remote.created) <= subscription.stripe_subscription_created_at
  end

  def trial_enabled_after_sync?(subscription, remote)
    return false if remote.metadata['chatoctave_paid_extension'] == 'true'

    remote.status == 'trialing' || (subscription.trial_enabled? && remote.status != 'active')
  end

  def interval_change_supported?(remote, item)
    remote.items.data.one? && remote.collection_method == 'charge_automatically' && item.price.recurring.usage_type == 'licensed' &&
      item.price.recurring.interval_count == 1 && item.price['billing_scheme'] == 'per_unit' &&
      %w[month year].include?(item.price.recurring.interval)
  end

  def stripe_details(remote, item)
    invoice = remote['latest_invoice']
    {
      amount_cents: item.price.unit_amount, currency: item.price.currency, quantity: item.quantity,
      interval: item.price.recurring.interval, interval_count: item.price.recurring.interval_count,
      cancel_at_period_end: remote.cancel_at_period_end, cancel_at: remote['cancel_at'], ended_at: remote['ended_at'],
      paid_extension: remote.metadata['chatoctave_paid_extension'] == 'true',
      schedule: remote['schedule'], pending_update: remote['pending_update'].present?,
      interval_change_supported: interval_change_supported?(remote, item),
      latest_invoice: invoice.is_a?(Stripe::Invoice) ? invoice.to_h.slice(:status, :total, :currency, :created) : nil
    }
  end

  def subscription_attributes(subscription, remote)
    item = remote.items.data.first
    stripe_period(remote, item).merge(
      stripe_subscription_id: remote.id, stripe_subscription_created_at: Time.zone.at(remote.created),
      payment_status: remote.status, billing_interval: item.price.recurring.interval,
      stripe_subscription_details: stripe_details(remote, item),
      stripe_checkout_session_id: %w[canceled incomplete_expired].include?(remote.status) ? subscription.stripe_checkout_session_id : nil,
      trial_enabled: trial_enabled_after_sync?(subscription, remote),
      trial_ends_at: remote.trial_end ? Time.zone.at(remote.trial_end) : subscription.trial_ends_at
    )
  end

  def stripe_period(remote, item)
    {
      period_started_at: Time.zone.at(remote['current_period_start'] || item['current_period_start']),
      period_ends_at: Time.zone.at(remote['current_period_end'] || item['current_period_end'])
    }
  end
end
