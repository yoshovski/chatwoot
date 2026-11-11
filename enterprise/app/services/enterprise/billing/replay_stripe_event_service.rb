# Runs a stored Stripe event again, for example from the Super Admin billing page (T10) or the console:
#   Enterprise::Billing::ReplayStripeEventService.new(stripe_event: StripeEvent.find_by!(stripe_id: 'evt_...')).perform
# Handlers re-read Stripe or only set a fact once, so a replay does not change state twice. The legacy plan-credit
# path (accounts billed through custom_attributes) adds credits on every run and is therefore skipped on replay.
class Enterprise::Billing::ReplayStripeEventService
  def initialize(stripe_event:)
    @stripe_event = stripe_event
  end

  def perform
    Enterprise::Billing::StripeEventProcessor.new(@stripe_event, replay: true).perform.reload
  end
end
