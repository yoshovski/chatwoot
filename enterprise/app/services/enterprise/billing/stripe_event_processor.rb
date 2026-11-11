# Runs the handlers for one stored Stripe event under a row lock and records the outcome on the row. Without replay
# a processed row is left alone, which makes the job idempotent by event id. A failure is written after the lock's
# transaction rolls back, so the row keeps the error (for the Super Admin billing page); it also goes to the exception
# tracker and is raised again so Sidekiq retries.
class Enterprise::Billing::StripeEventProcessor
  def initialize(stripe_event, replay: false)
    @stripe_event = stripe_event
    @replay = replay
  end

  def perform
    @stripe_event.with_lock do
      next if @stripe_event.processed? && !@replay

      @stripe_event.increment!(:attempts) # rubocop:disable Rails/SkipsModelValidations
      handle
    end
    @stripe_event
  rescue StandardError => e
    record_failure(e)
    raise
  end

  private

  def handle
    handler = Enterprise::Billing::HandleStripeEventService
    return @stripe_event.mark_processed!('ignored') unless handler.handled_type?(@stripe_event.event_type)

    handler.new.perform(event: @stripe_event.stripe_event, replay: @replay)
    @stripe_event.mark_processed!
  end

  def record_failure(exception)
    @stripe_event.reload
    @stripe_event.mark_failed!(exception, attempts: @stripe_event.attempts + 1)
    ChatwootExceptionTracker.new(exception, account: account_for_customer).capture_exception
  end

  def account_for_customer
    return if @stripe_event.stripe_customer_id.blank?

    AccountSubscription.find_by(stripe_customer_id: @stripe_event.stripe_customer_id)&.account
  end
end
