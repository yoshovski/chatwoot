# Moves a Stripe subscription that runs on a plan price to another plan or interval.
# Upgrade (a pricier plan, or the same plan billed yearly): now, with a prorated invoice charged at once.
# Downgrade (a cheaper plan, or the same plan billed monthly): at the end of the paid period, through a subscription
# schedule, so the account keeps what it paid for. Choosing the current plan again drops a pending downgrade.
# The plan, its features and a new AI allowance follow from the subscription webhook (AccountSubscriptionSyncService).
class Enterprise::Billing::AccountPlanChangeService
  Unavailable = Enterprise::Billing::AccountCheckoutService::Unavailable

  def initialize(account:)
    @account = account
  end

  def perform(plan:, interval:)
    result = @account.with_lock do
      remote = Enterprise::Billing::AccountSubscriptionSyncService.refresh(@account)
      subscription = @account.subscription_settings
      subscription.reload if subscription.persisted?
      raise Unavailable unless subscription.plan_change_available? && plan.purchasable? && remote_owned?(subscription, remote)

      change(remote, plan.stripe_price_id(interval), rank(plan, interval))
    end
    # Its own transaction: the plan's features follow an after-commit hook, which sees only the last save of a transaction.
    Enterprise::Billing::AccountSubscriptionSyncService.refresh(@account)
    result
  end

  private

  def change(remote, price_id, target_rank)
    item = remote.items.data.first
    current = BillingPlan.for_stripe_price(item.price.id)
    current_rank = rank(current, item.price.recurring.interval)
    schedule_id = Enterprise::Billing::AccountSubscriptionSyncService.schedule_id(remote)

    if price_id == item.price.id
      raise Unavailable if schedule_id.blank?

      Stripe::SubscriptionSchedule.release(schedule_id)
      { status: 'kept' }
    elsif (target_rank <=> current_rank).positive?
      upgrade(remote, item, price_id, schedule_id)
    else
      downgrade(remote, item, price_id, schedule_id)
    end
  end

  def upgrade(remote, item, price_id, schedule_id)
    Stripe::SubscriptionSchedule.release(schedule_id) if schedule_id.present?
    updated = Stripe::Subscription.update(remote.id, { items: [{ id: item.id, price: price_id }], proration_behavior: 'always_invoice',
                                                       payment_behavior: 'pending_if_incomplete', expand: ['latest_invoice'] })
    return { status: 'changed' } if updated['pending_update'].blank?

    # The card needs confirmation (3-D Secure): the change applies once the prorated invoice is paid.
    { status: 'payment_required', url: updated.latest_invoice.hosted_invoice_url }
  end

  def downgrade(remote, item, price_id, schedule_id)
    schedule_id ||= Stripe::SubscriptionSchedule.create(from_subscription: remote.id).id
    period_end = remote['current_period_end'] || item['current_period_end']
    Stripe::SubscriptionSchedule.update(
      schedule_id,
      end_behavior: 'release', proration_behavior: 'none',
      phases: [
        { start_date: remote['current_period_start'] || item['current_period_start'], end_date: period_end,
          items: [{ price: item.price.id, quantity: item.quantity }] },
        { start_date: period_end, items: [{ price: price_id, quantity: item.quantity }] }
      ]
    )
    { status: 'scheduled', effective_at: Time.zone.at(period_end) }
  end

  # Plans order by monthly price; on the same price, yearly ranks above monthly (it charges more now).
  def rank(plan, interval)
    raise Unavailable unless plan

    [plan.monthly_price_cents, interval == 'year' ? 1 : 0]
  end

  def remote_owned?(subscription, remote)
    remote && remote.customer == subscription.stripe_customer_id && remote.metadata['chatoctave_account_id'] == @account.id.to_s &&
      !remote.cancel_at_period_end && remote['cancel_at'].blank?
  end
end
