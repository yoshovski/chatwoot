# The numbers on the Super Admin billing overview (T10). Reads only the database: Stripe facts come from the stored
# subscription details and webhook events, never from a Stripe call. Enterprise::Billing::OverviewSnapshotJob runs it
# daily and keeps the result in Redis; the page reads that copy.
class Enterprise::Billing::OverviewService
  REDIS_KEY = 'SUPER_ADMIN::BILLING_OVERVIEW'.freeze
  PAYING_STATUSES = %w[active past_due manual].freeze
  LISTED_STATUSES = %w[active past_due trialing manual].freeze
  TRIAL_ENDING_WITHIN = 7.days
  NEAR_LIMIT_SHARE = 0.8
  CANCEL_EVENTS = %w[customer.subscription.deleted customer.subscription.updated].freeze

  def self.cached
    raw = Redis::Alfred.get(REDIS_KEY)
    raw.present? ? JSON.parse(raw) : nil
  rescue JSON::ParserError
    nil
  end

  def self.store!
    overview = new.perform
    Redis::Alfred.set(REDIS_KEY, overview.to_json)
    overview
  end

  def perform
    rows = account_rows
    ai_cost_status = add_ai_costs(rows)
    paying = rows.select { |row| row[:paying] }
    {
      computed_at: Time.current.iso8601, mrr_cents: mrr(paying), paying_count: paying.size,
      trials_count: rows.count { |row| row[:status] == 'trialing' }, trials_ending: trials_ending,
      past_due: rows.select { |row| row[:status] == 'past_due' }, near_limit: rows.select { |row| row[:near_limit] },
      cancellations: cancellations, accounts: rows, ai_cost_status: ai_cost_status
    }
  end

  private

  # Fills ai_cost_cents with the LiteLLM spend since each account's period started (one call per period start).
  # Returns not_connected, connected or unavailable; a LiteLLM failure leaves the costs empty and the rest stands.
  def add_ai_costs(rows)
    return 'not_connected' unless Enterprise::Billing::AiSpendService.configured?

    spend = Enterprise::Billing::AiSpendService.new
    rows.group_by { |row| row[:period_started_at] }.each do |start, list|
      costs = spend.spend_cents(from: start, to: Time.current)
      list.each { |row| row[:ai_cost_cents] = costs.fetch(row[:account_id], 0) }
    end
    'connected'
  rescue Enterprise::Billing::AiSpendService::Unavailable => e
    Rails.logger.warn("[billing overview] AI cost unavailable: #{e.message}")
    rows.each { |row| row[:ai_cost_cents] = nil }
    'unavailable'
  end

  def mrr(paying)
    paying.group_by { |row| row[:currency] }.transform_values { |list| list.sum { |row| row[:revenue_cents] } }
  end

  def subscriptions
    @subscriptions ||= AccountSubscription.includes(:account, :billing_plan).where(enabled: true).to_a
  end

  def account_rows
    subscriptions.filter_map do |subscription|
      next unless LISTED_STATUSES.include?(subscription.payment_status)
      next if subscription.payment_status == 'manual' && !subscription.manual_ai_access? && subscription.monthly_price_cents.zero?

      account_row(subscription)
    end
  end

  def account_row(subscription)
    revenue_cents, currency = monthly_revenue(subscription)
    limit = subscription.effective_limit
    used = subscription.consumed
    { account_id: subscription.account_id, name: subscription.account.name, plan: subscription.billing_plan&.name,
      status: subscription.payment_status, revenue_cents: revenue_cents, currency: currency,
      paying: PAYING_STATUSES.include?(subscription.payment_status) && revenue_cents.positive?,
      ai_used: used, ai_limit: limit, extra_left: subscription.extra_ai_conversations,
      near_limit: !limit.nil? && limit.positive? && used >= limit * NEAR_LIMIT_SHARE,
      past_due_since: [subscription.payment_failed_at, subscription.past_due_since].compact.min&.iso8601,
      period_started_at: subscription.quota_period.first, ai_cost_cents: nil }
  end

  # What the account pays per month: the live Stripe price when there is one, otherwise the saved price.
  # Discounts and taxes are not taken off.
  def monthly_revenue(subscription)
    details = subscription.stripe_subscription_details || {}
    return stripe_monthly_revenue(subscription, details) if subscription.live_stripe_subscription? && details['amount_cents'].present?

    cents = subscription.billing_interval == 'year' ? (subscription.annual_amount_cents / 12.0).round : subscription.monthly_price_cents
    [cents, subscription.currency]
  end

  def stripe_monthly_revenue(subscription, details)
    months = (details['interval'] == 'year' ? 12 : 1) * [details['interval_count'].to_i, 1].max
    amount = details['amount_cents'].to_i * [details['quantity'].to_i, 1].max
    [(amount / months.to_f).round, (details['currency'] || subscription.currency).to_s.downcase]
  end

  def trials_ending
    ending = subscriptions.select do |subscription|
      subscription.payment_status == 'trialing' && subscription.trial_ends_at&.between?(Time.current, TRIAL_ENDING_WITHIN.from_now)
    end
    ending.sort_by(&:trial_ends_at).map do |subscription|
      { account_id: subscription.account_id, name: subscription.account.name, trial_ends_at: subscription.trial_ends_at.iso8601 }
    end
  end

  # Subscriptions that ended this month, or were set to end, with Stripe's cancellation details. The latest event of a
  # subscription wins.
  def cancellations
    by_customer = AccountSubscription.where.not(stripe_customer_id: nil).includes(:account).index_by(&:stripe_customer_id)
    latest = {}
    StripeEvent.where(event_type: CANCEL_EVENTS, stripe_created_at: Time.current.beginning_of_month..)
               .order(:stripe_created_at).each do |event|
      subscription_id = event.payload.dig('data', 'object', 'id')
      row = cancellation_row(event, by_customer[event.stripe_customer_id])
      # A later update without a cancellation means the customer took it back.
      row ? latest[subscription_id] = row : latest.delete(subscription_id)
    end
    latest.values.sort_by { |row| row[:at] }.reverse
  end

  def cancellation_row(event, subscription)
    object = event.payload.dig('data', 'object').to_h
    return unless cancelling?(event, object)

    account = subscription&.account
    { account_id: account&.id, name: account&.name, at: event.stripe_created_at&.iso8601,
      state: event.event_type == 'customer.subscription.deleted' ? 'ended' : 'scheduled' }
      .merge(object['cancellation_details'].to_h.slice('reason', 'feedback', 'comment').symbolize_keys)
  end

  def cancelling?(event, object)
    event.event_type == 'customer.subscription.deleted' || object['cancel_at_period_end'] || object['cancel_at'].present?
  end
end
