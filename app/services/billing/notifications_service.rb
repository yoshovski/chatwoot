# Decides which billing emails (T08) are due for one account and sends each to the account's administrators once.
#
# Every email is worked out from the subscription's current state, so the daily Billing::NotificationsJob and the
# event hooks (a Stripe webhook, an AI conversation, a top-up) share one rule. A dated email is due from its date for
# DUE_WINDOW: a late daily run still sends it, and an old fact (for example a failure from last month, or the state
# at deploy time) never does. BillingNotification records each send under its own key.
class Billing::NotificationsService
  DUE_WINDOW = 2.days
  USAGE_WARNING_SHARE = 0.8
  WIN_BACK_AFTER = 14.days
  RENEWAL_NOTICE = 7.days
  TRIAL_NOTICES = { 'trial_ending_3' => 3.days, 'trial_ending_1' => 1.day }.freeze
  PAYMENT_REMINDER_DAYS = [0, 3, 6].freeze
  # Per-user opt-out covers these two only (AccountUser#billing_usage_emails).
  USAGE_KINDS = %w[usage_80 usage_100].freeze
  KINDS = (%w[trial_ending_3 trial_ending_1 trial_ended usage_80 usage_100 payment_failed_0 payment_failed_3 payment_failed_6
              payment_paused annual_renewal top_up_receipt auto_top_up_off cancellation_confirmed win_back]).freeze

  def initialize(subscription, now: Time.current)
    @subscription = subscription
    @account = subscription.account
    @now = now
  end

  def deliver_due
    return unless sendable?

    due_notices.each { |notice| deliver(**notice) }
  end

  def deliver_usage
    return unless sendable?

    usage_notices.each { |notice| deliver(**notice) }
  end

  # Whether a new AI conversation could have made a usage email due: cheap enough to ask on every one.
  def usage_notice_pending?
    notice = usage_notices.first
    notice.present? && !BillingNotification.sent?(@account, notice[:kind], notice[:key])
  end

  # The trial moved the account to its after-trial plan (EndTrialsJob).
  def deliver_trial_ended(trial_ends_at)
    return unless sendable?

    plan = @subscription.billing_plan
    deliver(kind: 'trial_ended', key: trial_ends_at.to_i,
            meta: { plan: plan&.name, ai_limit: plan&.ai_conversations_limit.to_i })
  end

  def deliver(kind:, key:, meta: {})
    raise ArgumentError, "unknown billing email #{kind}" unless KINDS.include?(kind)
    return false unless BillingNotification.claim(@account, kind, key)

    recipients = recipients_for(kind)
    recipients.each do |account_user|
      Billing::NotificationMailer.with(account: @account).notify(account_user, kind, meta.compact.stringify_keys).deliver_later
    end
    BillingNotification.where(account: @account, kind: kind, key: key.to_s).update_all(recipients_count: recipients.size) # rubocop:disable Rails/SkipsModelValidations
    true
  end

  private

  def sendable?
    @subscription.enabled? && @account.chatoctave_billing? && @account.active?
  end

  def recipients_for(kind)
    scope = @account.account_users.administrator.includes(:user).where.not(users: { confirmed_at: nil })
    scope = scope.where(billing_usage_emails: true) if USAGE_KINDS.include?(kind)
    scope.to_a
  end

  def due_notices
    trial_notices + usage_notices + payment_notices + renewal_notices + top_up_notices + auto_top_up_notices +
      cancellation_notices + win_back_notices
  end

  def due?(at)
    at <= @now && at > @now - DUE_WINDOW
  end

  def notice(kind, key, meta = {})
    { kind: kind, key: key, meta: meta }
  end

  # 3 days and 1 day before the trial ends. A trial Stripe runs turns into the paid plan; any other moves to Free.
  def trial_notices
    ends_at = @subscription.trial_ends_at
    return [] unless @subscription.trial_active? && @subscription.payment_status == 'trialing' && ends_at && ends_at > @now

    TRIAL_NOTICES.filter_map do |kind, before|
      next unless due?(ends_at - before)

      notice(kind, ends_at.to_i, ends_at: ends_at, plan: plan_name, paid_next: converts_after_trial?, amount: plan_amount)
    end
  end

  # At 80 % and at 100 % of the allowance, once per quota period (or once per capped trial). Extra conversations
  # keep the AI answering, so nothing is said while some are left.
  def usage_notices
    limit = @subscription.effective_limit
    return [] unless usage_counted?(limit)

    used = @subscription.consumed
    kind = if used >= limit then 'usage_100'
           elsif used >= (limit * USAGE_WARNING_SHARE).ceil then 'usage_80'
           end
    return [] unless kind

    [notice(kind, usage_key, used: used, limit: limit, trial: @subscription.trial_capped?, resets_at: @subscription.quota_period(at: @now).last,
                             can_top_up: @subscription.top_up_available?)]
  end

  # A limited allowance the AI is running on, with no extra conversations behind it.
  def usage_counted?(limit)
    !limit.nil? && limit.positive? && @subscription.payment_status != 'manual' &&
      [nil, 'limit_reached'].include?(@subscription.ai_pause_reason) && !@subscription.extra_ai_conversations.positive?
  end

  def usage_key
    @subscription.trial_capped? ? "trial-#{@subscription.trial_ends_at.to_i}" : @subscription.quota_period(at: @now).first.to_i
  end

  # Day 0, 3 and 6 of a failed renewal while the AI still answers, then once when the 7-day grace ends.
  def payment_notices
    failed_at = payment_failed_at
    return [] unless failed_at

    pause_at = failed_at + AccountSubscriptionAiAccess::PAST_DUE_GRACE
    notices = PAYMENT_REMINDER_DAYS.filter_map do |day|
      next unless pause_at > @now && due?(failed_at + day.days)

      notice("payment_failed_#{day}", failed_at.to_i, plan: plan_name, pauses_at: pause_at, day: day)
    end
    notices << notice('payment_paused', failed_at.to_i) if due?(pause_at) && @subscription.ai_pause_reason == 'payment_failed'
    notices
  end

  def payment_failed_at
    return if %w[canceled incomplete_expired].include?(@subscription.payment_status)
    return unless @subscription.payment_failed_at || @subscription.payment_status == 'past_due'

    [@subscription.payment_failed_at, @subscription.past_due_since].compact.min
  end

  def renewal_notices
    renews_at = @subscription.period_ends_at
    return [] unless renews_at && @subscription.billing_interval == 'year' && @subscription.payment_status == 'active'
    return [] unless @subscription.live_stripe_subscription? && cancels_at.nil? && due?(renews_at - RENEWAL_NOTICE)

    [notice('annual_renewal', renews_at.to_i, renews_at: renews_at, plan: plan_name, amount: subscription_amount)]
  end

  # One per pack paid through Stripe. Stripe sends the money receipt; this one says what the pack added.
  def top_up_notices
    @account.extra_ai_conversation_entries.where(reason: 'purchase').where.not(stripe_reference: nil)
            .where(created_at: (@now - DUE_WINDOW)..@now).map do |entry|
      notice('top_up_receipt', entry.id, count: entry.amount, expires_at: entry.expires_at)
    end
  end

  def auto_top_up_notices
    failed_at = @subscription.auto_top_up_failed_at
    return [] unless failed_at && !@subscription.auto_top_up_enabled? && due?(failed_at)

    [notice('auto_top_up_off', failed_at.to_i)]
  end

  def cancellation_notices
    ends_at = cancels_at
    return [] unless ends_at && ends_at > @now && @subscription.live_stripe_subscription?

    [notice('cancellation_confirmed', ends_at.to_i, ends_at: ends_at, plan: plan_name)]
  end

  # 14 days after a paid subscription ended, unless the account has a live one again.
  def win_back_notices
    ended = details['ended_at']
    return [] if ended.blank? || @subscription.live_stripe_subscription? || !paid_before?

    ended_at = Time.zone.at(ended.to_i)
    due?(ended_at + WIN_BACK_AFTER) ? [notice('win_back', ended.to_i)] : []
  end

  def details
    @subscription.stripe_subscription_details.to_h.stringify_keys
  end

  # Stripe schedules cancellations on cancel_at; older subscriptions only set cancel_at_period_end.
  def cancels_at
    return Time.zone.at(details['cancel_at'].to_i) if details['cancel_at'].present?

    @subscription.period_ends_at if details['cancel_at_period_end']
  end

  def paid_before?
    invoice = details['latest_invoice'].to_h.stringify_keys
    invoice['status'] == 'paid' && invoice['total'].to_i.positive?
  end

  def converts_after_trial?
    @subscription.live_stripe_subscription? && cancels_at.nil?
  end

  def plan_name
    @subscription.billing_plan&.name
  end

  def subscription_amount
    cents = details['amount_cents']
    return if cents.blank?

    { 'cents' => cents.to_i * [details['quantity'].to_i, 1].max, 'currency' => details['currency'] || @subscription.currency }
  end

  def plan_amount
    return subscription_amount if @subscription.live_stripe_subscription?

    cents = @subscription.billing_interval == 'year' ? @subscription.annual_amount_cents : @subscription.monthly_price_cents
    { 'cents' => cents, 'currency' => @subscription.currency } if cents.to_i.positive?
  end
end
