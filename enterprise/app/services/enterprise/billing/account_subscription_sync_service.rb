class Enterprise::Billing::AccountSubscriptionSyncService
  EVENT_TYPES = %w[customer.subscription.created customer.subscription.updated customer.subscription.deleted].freeze
  PAYMENT_EVENTS = %w[checkout.session.completed checkout.session.async_payment_succeeded].freeze

  def self.handle(event)
    service = new
    return service.sync_payment(event.data.object) if PAYMENT_EVENTS.include?(event.type)
    return false unless EVENT_TYPES.include?(event.type)

    service.sync_subscription(event.data.object)
  end

  def sync_subscription(object)
    subscription = AccountSubscription.find_by(stripe_customer_id: object.customer)
    return false unless subscription
    return true unless object['metadata'].to_h['chatoctave_account_id'] == subscription.account_id.to_s

    subscription.account.with_lock do
      subscription.reload
      # Read authoritative state so replayed or reordered webhooks do not roll back entitlements.
      remote = Stripe::Subscription.retrieve(object.id)
      return true if older_subscription?(subscription, remote)

      attributes = subscription_attributes(subscription, remote)
      attributes[:quota_anchor] = attributes[:period_started_at] if subscription.stripe_subscription_id.blank?
      subscription.update!(attributes)
    end
    true
  end

  def sync_payment(object)
    subscription = AccountSubscription.find_by(stripe_customer_id: object.customer)
    return false unless subscription

    revision = object['metadata'].to_h['chatoctave_payment_revision']
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

  def subscription_attributes(subscription, remote)
    item = remote.items.data.first
    {
      stripe_subscription_id: remote.id, stripe_subscription_created_at: Time.zone.at(remote.created),
      payment_status: remote.status, billing_interval: item.price.recurring.interval,
      period_started_at: Time.zone.at(remote['current_period_start'] || item['current_period_start']),
      period_ends_at: Time.zone.at(remote['current_period_end'] || item['current_period_end']),
      trial_enabled: trial_enabled_after_sync?(subscription, remote),
      trial_ends_at: remote.trial_end ? Time.zone.at(remote.trial_end) : subscription.trial_ends_at
    }
  end
end
