# The billing actions on an account's Super Admin page (T10). Each one writes who did it: a ledger row with the
# person and a note, or an audit row on the account subscription (shown on the account's billing timeline, not in the
# account's own audit log).
class Enterprise::Billing::AdminActionService
  class Refused < StandardError; end

  MAX_TRIAL_DAYS = 90
  MAX_EXTRA_CONVERSATIONS = 10_000
  COUPON_FORMAT = /\A[A-Za-z0-9_-]{1,64}\z/

  def initialize(account:, actor:)
    @account = account
    @actor = actor
  end

  # A trial Stripe runs moves its trial end in Stripe too; the webhook then syncs it back.
  def extend_trial(days)
    days = Integer(days, exception: false)
    refuse!('days') unless days&.between?(1, MAX_TRIAL_DAYS)

    @account.with_lock do
      refuse!('no_trial') unless trial_extendable?
      from = subscription.trial_ends_at
      ends_at = [from, Time.current].compact.max + days.days
      if subscription.stripe_subscription_id.present?
        Stripe::Subscription.update(subscription.stripe_subscription_id, trial_end: ends_at.to_i, proration_behavior: 'none')
      end
      subscription.update!(trial_ends_at: ends_at)
      record!('extend_trial', trial_ends_at: [from&.iso8601, ends_at.iso8601], days: days)
    end
  end

  def add_extra_conversations(amount, note)
    amount = Integer(amount, exception: false)
    refuse!('amount') unless amount&.between?(1, MAX_EXTRA_CONVERSATIONS)
    refuse!('note') if note.to_s.strip.blank?

    @account.with_lock do
      ExtraAiConversationEntry.credit!(account: @account, amount: amount, reason: 'adjustment', user: @actor, note: note.to_s.strip.first(255))
    end
  end

  # Stripe applies the coupon to the next invoices of the subscription.
  def apply_coupon(coupon)
    coupon = coupon.to_s.strip
    refuse!('coupon') unless COUPON_FORMAT.match?(coupon)
    refuse!('no_subscription') unless subscription&.live_stripe_subscription?

    Stripe::Subscription.update(subscription.stripe_subscription_id, discounts: [{ coupon: coupon }])
    record!('apply_coupon', coupon: coupon)
  end

  def pause_ai
    refuse!('no_subscription') unless subscription
    refuse!('already_paused') if subscription.ai_paused_at.present?

    subscription.update!(ai_paused_at: Time.current, ai_paused_reason: AccountSubscriptionAiAccess::ADMIN_PAUSE_REASON)
    record!('pause_ai')
  end

  # Also lifts a pause set by a Stripe dispute.
  def resume_ai
    refuse!('not_paused') unless subscription&.ai_paused_at
    previous = subscription.ai_paused_reason

    subscription.update!(ai_paused_at: nil, ai_paused_reason: nil)
    record!('resume_ai', paused_for: previous)
  end

  # One trial per website domain (T11): gives a public signup that was refused the trial, or lost it to a website
  # another trial had, the signup plan's trial from today. A later website no longer takes it away.
  def grant_trial
    signup = @account.account_signup
    refuse!('no_signup') unless signup
    refuse!('trial_granted') if signup.trial_granted?
    refuse!('paid') if subscription&.live_stripe_subscription?

    refused_for = signup.trial_refused_reason
    Signup::TrialService.new(@account).grant!
    record!('grant_trial', refused_for: refused_for, trial_ends_at: subscription.reload.trial_ends_at&.iso8601)
  end

  def replay_event(stripe_event_id)
    event = Enterprise::Billing::AccountTimelineService.new(account: @account).stripe_events.find_by(id: stripe_event_id)
    refuse!('event') unless event

    replayed = Enterprise::Billing::ReplayStripeEventService.new(stripe_event: event).perform
    record!('replay_event', stripe_event: event.stripe_id, event_type: event.event_type, status: replayed.status)
    replayed
  end

  private

  def subscription
    @account.account_subscription
  end

  def trial_extendable?
    return false unless subscription&.trial_enabled?
    return subscription.payment_status == 'trialing' if subscription.stripe_subscription_id.blank?

    subscription.payment_status == 'trialing' && subscription.live_stripe_subscription?
  end

  def record!(action, details = {})
    Audited.audit_class.create!(auditable: subscription, action: 'update', comment: "super_admin.#{action}",
                                audited_changes: details, user: @actor)
  end

  def refuse!(key)
    raise Refused, key
  end
end
