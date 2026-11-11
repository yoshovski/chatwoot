# Handles the Stripe events that record billing facts rather than re-reading the subscription: the facts the billing
# emails (T08), the AI limit (T01) and the Super Admin billing page (T10) read. Every handler is safe to run twice:
# it sets a fact from the event itself, keeps the first value, or re-reads Stripe before it records anything.
class Enterprise::Billing::StripeEventFactsService
  EVENT_TYPES = %w[
    invoice.payment_failed invoice.paid invoice.payment_action_required invoice.upcoming
    customer.subscription.trial_will_end checkout.session.expired checkout.session.async_payment_failed
    charge.refunded charge.dispute.created customer.deleted
  ].freeze
  DISPUTE_REASON = 'dispute'.freeze

  def initialize(event)
    @event = event
    @object = event.data.object
  end

  def perform
    return unless EVENT_TYPES.include?(@event.type)

    send("handle_#{@event.type.tr('.', '_')}")
  end

  private

  # Start of the payment-failure run (T01's 7-day grace, T08's day 0/3/6 emails). Kept until an invoice is paid.
  def handle_invoice_payment_failed
    record_unpaid_invoice_fact(:payment_failed_at)
  end

  def handle_invoice_payment_action_required
    record_unpaid_invoice_fact(:payment_action_required_at)
  end

  def handle_invoice_paid
    subscription&.update!(payment_failed_at: nil, payment_action_required_at: nil)
  end

  # Next renewal date for the annual renewal notice (T08). Renewal dates only move forward.
  def handle_invoice_upcoming
    return unless subscription

    upcoming_at = epoch(@object['next_payment_attempt'] || @object['period_end'])
    return if upcoming_at.nil?

    subscription.update!(upcoming_invoice_at: [subscription.upcoming_invoice_at, upcoming_at].compact.max)
  end

  # Stripe sends this three days before the trial ends (T08 sends the email).
  def handle_customer_subscription_trial_will_end
    return unless subscription

    notified_at = event_time
    return if subscription.trial_will_end_notified_at && subscription.trial_will_end_notified_at >= notified_at

    subscription.update!(trial_will_end_notified_at: notified_at)
  end

  # An expired or failed checkout must not block a new checkout.
  def handle_checkout_session_expired
    release_checkout_session
  end

  def handle_checkout_session_async_payment_failed
    release_checkout_session
    Enterprise::Billing::AccountSubscriptionSyncService.refresh(subscription.account) if subscription && @object['mode'] == 'subscription'
  end

  # A refund can end or change the subscription in Stripe; read it again.
  def handle_charge_refunded
    Enterprise::Billing::AccountSubscriptionSyncService.refresh(subscription.account) if subscription
  end

  # A dispute pauses the AI for the account and tells Super Admin, once per pause.
  def handle_charge_dispute_created
    @customer_id = Stripe::Charge.retrieve(@object['charge']).customer if @object['charge'].present?
    return unless subscription

    paused = false
    subscription.with_lock do
      next if subscription.ai_paused_at.present?

      subscription.update!(ai_paused_at: event_time, ai_paused_reason: DISPUTE_REASON)
      paused = true
    end
    notify_dispute if paused
  end

  # The Stripe customer is gone, and its subscriptions with it. Manual accounts keep their manual status.
  def handle_customer_deleted
    return unless subscription

    attributes = { stripe_customer_id: nil, stripe_subscription_id: nil, stripe_checkout_session_id: nil }
    attributes[:payment_status] = 'canceled' unless subscription.payment_status == 'manual'
    subscription.update!(attributes)
  end

  def record_unpaid_invoice_fact(column)
    return unless subscription
    # Re-read the invoice so a late or replayed event does not reopen a failure that was paid since.
    return if @object['id'].present? && Stripe::Invoice.retrieve(@object['id']).status == 'paid'

    subscription.with_lock do
      subscription.update!(column => event_time) if subscription.public_send(column).nil?
    end
  end

  def release_checkout_session
    return unless subscription && subscription.stripe_checkout_session_id == @object['id']

    subscription.update!(stripe_checkout_session_id: nil)
  end

  def notify_dispute
    AdministratorNotifications::BillingAlertMailer.dispute_created(
      subscription.account,
      dispute_id: @object['id'], amount_cents: @object['amount'], currency: @object['currency'], reason: @object['reason']
    ).deliver_later
  end

  def customer_id
    @customer_id ||= @event.type == 'customer.deleted' ? @object['id'] : @object['customer']
  end

  def subscription
    return if customer_id.blank?

    @subscription ||= AccountSubscription.find_by(stripe_customer_id: customer_id)
  end

  def event_time
    epoch(@event.created) || Time.current
  end

  def epoch(value)
    value.present? ? Time.zone.at(value.to_i) : nil
  end
end
