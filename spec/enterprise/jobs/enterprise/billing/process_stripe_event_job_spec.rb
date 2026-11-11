require 'rails_helper'

RSpec.describe Enterprise::Billing::ProcessStripeEventJob do
  let(:event) { build_stripe_event(id: 'evt_job', type: 'invoice.paid', object: { id: 'in_1', customer: 'cus_job' }) }
  let(:stripe_event) { StripeEvent.record!(event) }
  let(:handler) { instance_double(Enterprise::Billing::HandleStripeEventService, perform: true) }

  before { allow(Enterprise::Billing::HandleStripeEventService).to receive(:new).and_return(handler) }

  it 'handles the event once and marks it processed' do
    described_class.perform_now(stripe_event.id)
    described_class.perform_now(stripe_event.id)

    expect(handler).to have_received(:perform).once
    expect(stripe_event.reload).to have_attributes(status: 'processed', attempts: 1, processed_at: be_present, error: nil)
  end

  it 'keeps the error on the row, reports it and raises so Sidekiq retries' do
    allow(handler).to receive(:perform).and_raise(Stripe::APIConnectionError, 'Stripe is down')
    tracker = instance_double(ChatwootExceptionTracker, capture_exception: true)
    allow(ChatwootExceptionTracker).to receive(:new).and_return(tracker)

    expect { described_class.perform_now(stripe_event.id) }.to raise_error(Stripe::APIConnectionError)

    expect(stripe_event.reload).to have_attributes(status: 'failed', processed_at: nil)
    expect(stripe_event.error).to include('Stripe is down')
    expect(tracker).to have_received(:capture_exception)
  end

  it 'handles a failed event again on retry' do
    stripe_event.update!(status: 'failed', error: 'earlier failure')

    described_class.perform_now(stripe_event.id)

    expect(stripe_event.reload).to have_attributes(status: 'processed', error: nil)
  end
end
