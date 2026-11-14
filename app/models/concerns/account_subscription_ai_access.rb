# Whether the AI agent may reply for the account, and why not. This is the only copy of the rule: Message,
# AgentBotListener and Captain's OwnershipService all ask Account#ai_reply_allowed?, which comes here.
module AccountSubscriptionAiAccess
  extend ActiveSupport::Concern

  PAST_DUE_GRACE = 7.days
  STOPPED_REASONS = { 'paused' => 'paused', 'unpaid' => 'payment_failed', 'incomplete' => 'payment_failed' }.freeze
  # ai_paused_reason of a pause set by hand in Super Admin (T10); a Stripe dispute writes 'dispute'.
  ADMIN_PAUSE_REASON = 'admin'.freeze

  included do
    before_save :track_past_due_since, if: :will_save_change_to_payment_status?
  end

  def ai_reply_allowed?(conversation = nil)
    ai_pause_reason(conversation).nil?
  end

  # nil while the AI may reply, otherwise email_unconfirmed, limit_reached, trial_ended, payment_failed, paused or no_plan.
  def ai_pause_reason(conversation = nil)
    # A public signup gets AI replies once its person confirmed their email (T11).
    return 'email_unconfirmed' if account.signup_email_unconfirmed?

    subscription_pause_reason(conversation)
  end

  # Extra AI conversations bought and not yet used or expired (ExtraAiConversationEntry).
  def extra_ai_conversations
    ExtraAiConversationEntry.balance(account)
  end

  # Whether a new AI conversation still fits the plan allowance. When it does not, it takes an extra one.
  # Manual accounts and accounts without a limit have no allowance to run out of.
  def allowance_left?
    limit = effective_limit
    limit.nil? || payment_status == 'manual' || consumed < limit
  end

  private

  def subscription_pause_reason(conversation)
    # ai_paused_at is set by a Stripe dispute (Enterprise::Billing::StripeEventFactsService) or by Super Admin
    # (SuperAdmin::AccountBillingController); Super Admin clears it.
    return held_pause_reason if ai_paused_at.present?

    case payment_status
    # Invoiced outside Stripe: only accounts marked in Super Admin get AI replies, without a limit, as before T01.
    when 'manual' then 'no_plan' unless manual_ai_access?
    when 'trialing', 'active', 'past_due' then running_pause_reason(conversation)
    # canceled and incomplete_expired: the subscription is over. After a trial that was never paid, say so.
    else STOPPED_REASONS.fetch(payment_status) { trial_enabled? ? 'trial_ended' : 'no_plan' }
    end
  end

  def held_pause_reason
    ai_paused_reason == ADMIN_PAUSE_REASON ? 'paused' : 'payment_failed'
  end

  def running_pause_reason(conversation)
    return 'payment_failed' if payment_status == 'past_due' && !past_due_grace?
    return 'trial_ended' if payment_status == 'trialing' && trial_active? && !(trial_ends_at && trial_ends_at > Time.current)

    limit_pause_reason(conversation)
  end

  def limit_pause_reason(conversation)
    limit = effective_limit
    return if limit.nil?
    # A plan without AI conversations (Free) has no AI at all; that is not a limit the account reached.
    return 'no_plan' if limit.zero? && !trial_capped?

    'limit_reached' unless within_limit?(conversation, limit)
  end

  # Allowance first, then the extra balance. An open window keeps replying for its 24 hours: an extra one always, an
  # included one while it is within the allowance.
  def within_limit?(conversation, limit)
    window = conversation && account.conversation_usage_windows.where(conversation: conversation).where('ends_at > ?', Time.current).last
    return consumed < limit || extra_ai_conversations.positive? unless window
    return true if window.extra?

    counted_windows.where('(started_at, id) <= (?, ?)', window.started_at, window.id).count <= limit
  end

  # Billing page: the day a past-due account's AI stops replying.
  def ai_pauses_at
    return unless payment_status == 'past_due'

    failed_at = [payment_failed_at, past_due_since].compact.min
    (failed_at || Time.current) + PAST_DUE_GRACE
  end

  # Grace counts from the first failed invoice: payment_failed_at from the Stripe event, or, when that event was
  # missed, the moment the subscription first went past_due.
  def past_due_grace?
    failed_at = [payment_failed_at, past_due_since].compact.min
    failed_at.nil? || failed_at > PAST_DUE_GRACE.ago
  end

  def track_past_due_since
    self.past_due_since = payment_status == 'past_due' ? (past_due_since || Time.current) : nil
  end
end
