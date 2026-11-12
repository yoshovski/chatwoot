# Packs of extra AI conversations (T07). The request that starts a payment never credits: the Stripe webhook does,
# through ExtraAiConversationEntry.credit! with the Stripe id as the ledger key. Auto top-up buys one pack when few
# AI conversations are left, at most auto_top_up_max_packs per quota period.
module AccountSubscriptionTopUp
  extend ActiveSupport::Concern

  PACK_CONVERSATIONS = 50
  PACK_PRICE_CENTS = 800
  AUTO_TOP_UP_THRESHOLD = 5
  MAX_PACKS = 1..10
  # An automatic payment whose webhook never came does not block auto top-up for longer than this.
  PENDING_TIMEOUT = 1.hour
  HISTORY_SIZE = 10

  included do
    validates :auto_top_up_max_packs, numericality: { only_integer: true, in: MAX_PACKS }
  end

  # Packs are for paying subscribers billed through Stripe.
  def top_up_available?
    enabled? && stripe_customer_id.present? && live_stripe_subscription? && %w[active trialing].include?(payment_status) &&
      ai_pause_reason_allows_top_up? && (!ChatwootApp.enterprise? || account.billing_provider == 'stripe')
  end

  # Allowance left in the period plus the extra balance; nil when the plan sets no limit.
  def ai_conversations_left
    limit = effective_limit
    return if limit.nil? || payment_status == 'manual'

    [limit - consumed, 0].max + extra_ai_conversations
  end

  def auto_top_ups_this_period
    auto_top_up_period_start == quota_period.first ? auto_top_up_count : 0
  end

  def auto_top_up_due?
    return false unless auto_top_up_enabled? && top_up_available?
    return false if auto_top_up_pending_at && auto_top_up_pending_at > PENDING_TIMEOUT.ago
    return false if auto_top_ups_this_period >= auto_top_up_max_packs

    left = ai_conversations_left
    !left.nil? && left <= AUTO_TOP_UP_THRESHOLD
  end

  def request_auto_top_up
    return unless ChatwootApp.enterprise? && auto_top_up_due?

    Enterprise::Billing::AutoTopUpJob.perform_later(account_id)
  end

  # Counts the pack against the monthly ceiling and marks it in flight. Returns the step that names the payment's
  # idempotency key, so a retried job charges the same pack instead of a new one. The caller holds the account lock.
  def start_auto_top_up!
    period_start = quota_period.first
    count = auto_top_ups_this_period + 1
    update!(auto_top_up_period_start: period_start, auto_top_up_count: count, auto_top_up_pending_at: Time.current)
    "#{period_start.to_i}-#{count}"
  end

  # A failed automatic payment switches auto top-up off; the Billing page says so (and T08 emails the administrators).
  def auto_top_up_failed!
    update!(auto_top_up_enabled: false, auto_top_up_pending_at: nil, auto_top_up_failed_at: Time.current)
  end

  def top_up_summary
    {
      available: top_up_available?,
      pack: { conversations: PACK_CONVERSATIONS, amount_cents: PACK_PRICE_CENTS, currency: currency },
      auto: { enabled: auto_top_up_enabled?, max_packs: auto_top_up_max_packs, threshold: AUTO_TOP_UP_THRESHOLD,
              used_this_period: auto_top_ups_this_period, failed_at: auto_top_up_failed_at },
      history: top_up_history
    }
  end

  private

  # A pack cannot restart an AI that is off for another reason (Free plan, ended trial, failed payment).
  def ai_pause_reason_allows_top_up?
    [nil, 'limit_reached'].include?(ai_pause_reason)
  end

  def top_up_history
    account.extra_ai_conversation_entries.where.not(reason: 'usage').order(created_at: :desc).limit(HISTORY_SIZE).map do |entry|
      entry.slice(:id, :reason, :amount, :remaining, :expires_at, :created_at)
    end
  end
end
