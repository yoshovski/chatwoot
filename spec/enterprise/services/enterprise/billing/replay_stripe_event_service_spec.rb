require 'rails_helper'

RSpec.describe Enterprise::Billing::ReplayStripeEventService do
  let(:account) { create(:account) }
  let!(:subscription) do
    account.create_account_subscription!(quota_anchor: Time.current, enabled: true, stripe_customer_id: 'cus_replay', payment_status: 'active')
  end
  let(:created) { 1.day.ago.change(usec: 0) }

  before do
    allow(Stripe::Charge).to receive(:retrieve).and_return(Stripe::Charge.construct_from(id: 'ch_1', customer: 'cus_replay'))
    delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    allow(AdministratorNotifications::BillingAlertMailer).to receive(:dispute_created).and_return(delivery)
  end

  def stored(type, object)
    StripeEvent.record!(build_stripe_event(type: type, object: object, created: created.to_i))
  end

  it 'runs a processed event again without changing state twice' do
    stripe_event = stored('charge.dispute.created', { id: 'dp_1', charge: 'ch_1', amount: 100, currency: 'eur' })
    Enterprise::Billing::ProcessStripeEventJob.perform_now(stripe_event.id)
    paused_at = subscription.reload.ai_paused_at

    result = described_class.new(stripe_event: stripe_event).perform

    expect(result).to have_attributes(status: 'processed', attempts: 2)
    expect(subscription.reload.ai_paused_at).to eq(paused_at)
    expect(AdministratorNotifications::BillingAlertMailer).to have_received(:dispute_created).once
  end

  it 'processes a failed event' do
    allow(Stripe::Invoice).to receive(:retrieve).and_return(Stripe::Invoice.construct_from(id: 'in_1', status: 'open'))
    allow(Enterprise::Billing::AccountSubscriptionSyncService).to receive(:refresh)
    stripe_event = stored('invoice.payment_failed', { id: 'in_1', customer: 'cus_replay' })
    stripe_event.update!(status: 'failed', error: 'Stripe::APIConnectionError')

    expect(described_class.new(stripe_event: stripe_event).perform).to have_attributes(status: 'processed', error: nil)
    expect(subscription.reload.payment_failed_at).to eq(created)
  end

  it 'skips the legacy plan-credit path on replay' do
    legacy = instance_double(Enterprise::Billing::HandleStripeEventService)
    allow(Enterprise::Billing::HandleStripeEventService).to receive(:new).and_return(legacy)
    allow(legacy).to receive(:perform)
    stripe_event = stored('customer.subscription.updated', { id: 'sub_1', customer: 'cus_legacy' })

    described_class.new(stripe_event: stripe_event).perform

    expect(legacy).to have_received(:perform).with(event: anything, replay: true)
  end
end
