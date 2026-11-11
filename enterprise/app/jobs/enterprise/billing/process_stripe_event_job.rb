# Handles one stored Stripe event. Idempotent by event id: Enterprise::Billing::StripeEventProcessor locks the row
# and never handles a processed row again, so a second enqueue or a Sidekiq retry after success does nothing.
class Enterprise::Billing::ProcessStripeEventJob < ApplicationJob
  queue_as :high

  def perform(stripe_event_id)
    stripe_event = StripeEvent.find_by(id: stripe_event_id)
    return if stripe_event.nil? || stripe_event.processed?

    Enterprise::Billing::StripeEventProcessor.new(stripe_event).perform
  end
end
