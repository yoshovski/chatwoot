# Verifies the signature, stores the event once and answers 200. Enterprise::Billing::ProcessStripeEventJob does the
# work, so Stripe never waits on Stripe calls or account locks, and a redelivered event is a no-op.
class Enterprise::Webhooks::StripeController < ActionController::API
  def process_payload
    event = verified_event
    return head :bad_request if event.nil?

    store(event)
    head :ok
  end

  private

  def verified_event
    secret = ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)
    Rails.logger.error('[stripe] STRIPE_WEBHOOK_SECRET is blank; webhook events cannot be verified') if secret.blank?

    Stripe::Webhook.construct_event(request.body.read, request.headers['Stripe-Signature'], secret.to_s)
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    nil
  end

  def store(event)
    return if StripeEvent.exists?(stripe_id: event.id)

    stripe_event = StripeEvent.record!(event)
    if Enterprise::Billing::HandleStripeEventService.handled_type?(stripe_event.event_type)
      Enterprise::Billing::ProcessStripeEventJob.perform_later(stripe_event.id)
    else
      stripe_event.mark_processed!('ignored')
    end
  rescue ActiveRecord::RecordNotUnique
    # The same event arrived twice at the same moment; the first request stored it.
    nil
  end
end
