# Account-locked decisions with Stripe idempotency keys. Webhooks and page refreshes use the same sync service.
class Enterprise::Billing::CancellationService
  Unavailable = Enterprise::Billing::AccountCheckoutService::Unavailable

  def initialize(account:, actor:)
    @account = account
    @actor = actor
  end

  def start(reason: 'other', feature: nil)
    @account.with_lock do
      remote = refresh!
      raise Unavailable if canceling?(remote)

      attempt = AccountCancellation.create!(account: @account, user: @actor, stripe_subscription_id: remote.id, reason: reason, feature: feature)
      { id: attempt.id, period_ends_at: subscription.period_ends_at, discount_available: discount_available?(remote),
        pause_available: retention_available?(remote), smaller_plans: smaller_plans(remote).map(&:catalog_entry) }
    end
  end

  def decide(id:, action:, reason:, feature: nil, **offer)
    @account.with_lock do
      attempt = AccountCancellation.where(account: @account).find(id)
      # A retried completed request never runs another Stripe operation.
      return { status: attempt.outcome } unless attempt.outcome == 'started'

      remote = refresh!
      raise Unavailable unless remote.id == attempt.stripe_subscription_id

      attempt.assign_attributes(reason: reason, feature: feature)
      if action == 'confirm'
        cancel(remote, attempt)
      else
        raise Unavailable if canceling?(remote)

        accept(remote, attempt, offer[:months], offer[:plan])
      end
      attempt.save!
      { status: attempt.outcome }
    end
  end

  def dismiss(id:, reason:, feature: nil)
    @account.with_lock do
      attempt = AccountCancellation.where(account: @account).find(id)
      attempt.update!(reason: reason, feature: feature, outcome: 'kept') if attempt.outcome == 'started'
      { status: attempt.outcome }
    end
  end

  def keep
    @account.with_lock do
      remote = refresh!
      raise Unavailable unless canceling?(remote)

      updated = client.v1.subscriptions.update(remote.id, (remote.cancel_at_period_end ? { cancel_at_period_end: false } : { cancel_at: '' }))
      sync(updated)
      record(remote, 'kept')
      { status: 'kept' }
    end
  end

  def resume
    @account.with_lock do
      remote = refresh!
      raise Unavailable if remote['pause_collection'].blank?

      updated = client.v1.subscriptions.update(remote.id, { pause_collection: '', proration_behavior: 'none' })
      sync(updated)
      record(remote, 'resumed')
      { status: 'resumed' }
    end
  end

  private

  def client
    @client ||= Stripe::StripeClient.new(ENV.fetch('STRIPE_SECRET_KEY'))
  end

  def subscription
    @account.account_subscription
  end

  def refresh!
    raise Unavailable unless @account.billing_provider == 'stripe'
    raise Unavailable unless subscription&.enabled?

    remote = Enterprise::Billing::AccountSubscriptionSyncService.refresh(@account)
    raise Unavailable unless remote
    raise Unavailable unless owned?(remote) &&
                             %w[active trialing past_due unpaid paused incomplete].include?(remote.status)

    remote
  end

  def owned?(remote)
    remote.customer == subscription.stripe_customer_id && remote.metadata['chatoctave_account_id'] == @account.id.to_s
  end

  def sync(remote)
    Enterprise::Billing::AccountSubscriptionSyncService.new.sync_remote(subscription, remote)
  end

  def canceling?(remote)
    remote.cancel_at_period_end || remote['cancel_at'].present?
  end

  def retention_available?(remote)
    remote.status == 'active' && remote['pending_update'].blank? && remote['pause_collection'].blank? &&
      Enterprise::Billing::AccountSubscriptionSyncService.schedule_id(remote).blank?
  end

  def discount_available?(remote)
    monthly = remote.items.data.one? && remote.items.data.first.price.recurring.interval == 'month' &&
              remote.items.data.first.price.recurring.interval_count == 1
    monthly && retention_available?(remote) && undiscounted?(remote) &&
      remote.metadata['chatoctave_retention_attempt'].blank? && !AccountCancellation.exists?(account: @account, outcome: 'discounted')
  end

  def undiscounted?(remote)
    remote['discounts'].blank? && remote['discount'].blank?
  end

  def smaller_plans(remote)
    return [] unless subscription.plan_change_available? && retention_available?(remote)

    current = subscription.stripe_plan
    BillingPlan.ordered.select do |plan|
      plan.purchasable? && plan.currency == current.currency && plan.monthly_price_cents < current.monthly_price_cents
    end
  end

  def cancel(remote, attempt)
    schedule = Enterprise::Billing::AccountSubscriptionSyncService.schedule_id(remote)
    client.v1.subscription_schedules.release(schedule) if schedule.present?
    updated = client.v1.subscriptions.update(remote.id, { cancel_at_period_end: true, proration_behavior: 'none' },
                                             { idempotency_key: "cancel-#{attempt.id}" })
    sync(updated)
    attempt.outcome = 'canceled'
  end

  def accept(remote, attempt, months, plan)
    case attempt.reason
    when 'expensive' then discount(remote, attempt)
    when 'unused' then pause(remote, attempt, months)
    when 'feature' then downgrade(remote, attempt, plan)
    when 'quality' then attempt.outcome = 'setup_requested'
    else raise Unavailable
    end
  end

  def discount(remote, attempt)
    # The metadata also reconciles a Stripe success followed by a lost response or database rollback.
    unless remote.metadata['chatoctave_retention_attempt'] == attempt.id.to_s
      raise Unavailable unless discount_available?(remote)

      coupon = client.v1.coupons.create({ percent_off: 30, duration: 'repeating', duration_in_months: 3, max_redemptions: 1,
                                          name: '30% off for 3 months' }, { idempotency_key: "retention-coupon-#{attempt.id}" })
      updated = client.v1.subscriptions.update(remote.id,
                                               { discounts: [{ coupon: coupon.id }], proration_behavior: 'none',
                                                 metadata: { chatoctave_retention_attempt: attempt.id.to_s } },
                                               { idempotency_key: "retention-#{attempt.id}" })
      sync(updated)
    end
    attempt.outcome = 'discounted'
  end

  def pause(remote, attempt, months)
    return reconcile_pause(remote, attempt) if remote.metadata['chatoctave_pause_attempt'] == attempt.id.to_s &&
                                               remote['pause_collection'].present?
    raise Unavailable unless retention_available?(remote)

    resumes_at = attempt.created_at.advance(months: months).to_i
    updated = client.v1.subscriptions.update(remote.id,
                                             { pause_collection: { behavior: 'void', resumes_at: resumes_at },
                                               metadata: { chatoctave_pause_attempt: attempt.id.to_s }, proration_behavior: 'none' },
                                             { idempotency_key: "pause-#{attempt.id}" })
    sync(updated)
    attempt.outcome = 'paused'
    attempt.details = { resumes_at: resumes_at, months: months }
  end

  # A Stripe success followed by a lost response: record what Stripe already holds.
  def reconcile_pause(remote, attempt)
    attempt.outcome = 'paused'
    attempt.details = { resumes_at: remote['pause_collection']['resumes_at'] }
  end

  def downgrade(remote, attempt, plan)
    raise Unavailable unless smaller_plans(remote).include?(plan)

    result = Enterprise::Billing::AccountPlanChangeService.new(account: @account).perform(plan: plan, interval: subscription.billing_interval)
    attempt.outcome = 'downgraded'
    attempt.details = { plan_id: plan.id, effective_at: result[:effective_at] }
  end

  def record(remote, outcome)
    AccountCancellation.create!(account: @account, user: @actor, stripe_subscription_id: remote.id, reason: 'other', outcome: outcome)
  end
end
