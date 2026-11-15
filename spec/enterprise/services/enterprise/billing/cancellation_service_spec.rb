require 'rails_helper'

describe Enterprise::Billing::CancellationService do
  subject(:service) { described_class.new(account: account, actor: user) }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let!(:plan) do
    create(:billing_plan, name: 'Growth', monthly_price_cents: 7900).tap do |row|
      row.update!(stripe_monthly_price_id: 'price_growth', stripe_annual_price_id: 'price_growth_year')
    end
  end
  let!(:starter) do
    create(:billing_plan, name: 'Starter', monthly_price_cents: 2900).tap do |row|
      row.update!(stripe_monthly_price_id: 'price_starter', stripe_annual_price_id: 'price_starter_year')
    end
  end
  let(:subscription) { account.account_subscription }
  let(:remote) do
    Stripe::Subscription.construct_from(
      id: 'sub_cancel', object: 'subscription', customer: 'cus_cancel', status: 'active', created: 40.days.ago.to_i,
      metadata: { chatoctave_account_id: account.id.to_s }, cancel_at_period_end: false, collection_method: 'charge_automatically',
      schedule: nil, trial_end: nil,
      items: { data: [{ id: 'si_cancel', quantity: 1, current_period_start: 10.days.ago.to_i, current_period_end: 20.days.from_now.to_i,
                        price: { id: 'price_growth', unit_amount: 7900, currency: 'eur', billing_scheme: 'per_unit',
                                 recurring: { interval: 'month', interval_count: 1, usage_type: 'licensed' } } }] }
    )
  end
  let(:subscriptions_api) { instance_double(Stripe::SubscriptionService) }
  let(:coupons_api) { instance_double(Stripe::CouponService) }
  let(:schedules_api) { instance_double(Stripe::SubscriptionScheduleService, release: nil) }
  let(:v1) { instance_double(Stripe::V1Services, subscriptions: subscriptions_api, coupons: coupons_api, subscription_schedules: schedules_api) }
  let(:client) { instance_double(Stripe::StripeClient, v1: v1) }

  around { |example| with_modified_env('STRIPE_SECRET_KEY' => 'local-test-placeholder') { example.run } }

  before do
    account.update!(subscription_settings: { billing_plan_id: plan.id })
    subscription.update!(stripe_customer_id: 'cus_cancel', stripe_subscription_id: 'sub_cancel', payment_status: 'active')
    allow(Stripe::Subscription).to receive(:retrieve).and_return(remote)
    allow(Stripe::StripeClient).to receive(:new).and_return(client)
    allow(coupons_api).to receive(:create).and_return(Stripe::Coupon.construct_from(id: 'coupon_retention'))
    allow(subscriptions_api).to receive(:update) do |_id, attributes, _options|
      data = remote.to_h.merge(attributes)
      data[:metadata] = remote.metadata.to_h.merge(attributes.fetch(:metadata, {}))
      updated = Stripe::Subscription.construct_from(data)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(updated)
      updated
    end
  end

  it 'starts with only smaller purchasable plans and the available offers' do
    result = service.start(reason: 'expensive')
    expect(result).to include(discount_available: true, pause_available: true)
    expect(result[:smaller_plans].pluck(:id)).to eq([starter.id])
    expect(AccountCancellation.find(result[:id])).to have_attributes(account: account, user: user, reason: 'expensive', outcome: 'started')
  end

  it 'cancels at period end and keeps AI available until then' do
    attempt = service.start
    expect(service.decide(id: attempt[:id], action: 'confirm', reason: 'other')).to eq(status: 'canceled')
    expect(subscriptions_api).to have_received(:update).with('sub_cancel', { cancel_at_period_end: true, proration_behavior: 'none' },
                                                             { idempotency_key: "cancel-#{attempt[:id]}" })
    expect(subscription.reload.stripe_subscription_details['cancel_at_period_end']).to be(true)
    expect(subscription.ai_reply_allowed?).to be(true)
  end

  it 'releases a pending downgrade before cancellation' do
    attempt = service.start
    remote['schedule'] = 'sub_schedule'
    service.decide(id: attempt[:id], action: 'confirm', reason: 'feature', feature: 'A better search')
    expect(schedules_api).to have_received(:release).with('sub_schedule')
    expect(AccountCancellation.find(attempt[:id]).feature).to eq('A better search')
  end

  it 'applies a three-month coupon once per account, including after switching subscriptions' do
    attempt = service.start(reason: 'expensive')
    service.decide(id: attempt[:id], action: 'accept', reason: 'expensive')
    expect(coupons_api).to have_received(:create).with(
      hash_including(percent_off: 30, duration: 'repeating', duration_in_months: 3, max_redemptions: 1),
      { idempotency_key: "retention-coupon-#{attempt[:id]}" }
    )
    expect(AccountCancellation.find(attempt[:id]).outcome).to eq('discounted')
    remote['metadata'] = { chatoctave_account_id: account.id.to_s }
    remote['discounts'] = []
    replacement = Stripe::Subscription.construct_from(remote.to_h.merge(id: 'sub_replacement'))
    allow(Stripe::Subscription).to receive(:retrieve).and_return(replacement)
    expect(service.start[:discount_available]).to be(false)
  end

  it 'does not give an annual subscription a three-month coupon' do
    remote.items.data.first.price.recurring.interval = 'year'
    attempt = service.start
    expect(attempt[:discount_available]).to be(false)
    expect { service.decide(id: attempt[:id], action: 'accept', reason: 'expensive') }.to raise_error(described_class::Unavailable)
  end

  it 'does not replace an existing discount' do
    remote['discounts'] = ['di_existing']
    expect(service.start[:discount_available]).to be(false)
  end

  it 'reconciles a successful discount whose response was lost' do
    attempt = service.start
    remote.metadata['chatoctave_retention_attempt'] = attempt[:id].to_s
    service.decide(id: attempt[:id], action: 'accept', reason: 'expensive')
    expect(coupons_api).not_to have_received(:create)
    expect(AccountCancellation.find(attempt[:id]).outcome).to eq('discounted')
  end

  it 'does not repeat a completed action' do
    attempt = service.start
    2.times { service.decide(id: attempt[:id], action: 'accept', reason: 'expensive') }
    expect(coupons_api).to have_received(:create).once
    expect(subscriptions_api).to have_received(:update).once
  end

  it 'keeps the discount available after Stripe rejects it' do
    attempt = service.start
    allow(subscriptions_api).to receive(:update).and_raise(Stripe::APIConnectionError.new('unavailable'))
    expect { service.decide(id: attempt[:id], action: 'accept', reason: 'expensive') }.to raise_error(Stripe::APIConnectionError)
    expect(AccountCancellation.find(attempt[:id]).outcome).to eq('started')
    expect(service.start[:discount_available]).to be(true)
  end

  [1, 2, 3].each do |months|
    it "pauses collection and AI for #{months} months, and schedules a local refresh" do
      attempt = service.start
      row = AccountCancellation.find(attempt[:id])
      expect { service.decide(id: row.id, action: 'accept', reason: 'unused', months: months) }
        .to have_enqueued_job(Enterprise::Billing::ResumeCollectionJob).with(account.id, 'sub_cancel')
      expect(subscription.reload.payment_status).to eq('paused')
      expect(subscription.ai_pause_reason).to eq('paused')
      expect(subscription.stripe_subscription_details['pause_collection']).to include('behavior' => 'void',
                                                                                      'resumes_at' => row.created_at.advance(months: months).to_i)
    end
  end

  it 'requests setup help without changing Stripe' do
    attempt = service.start
    service.decide(id: attempt[:id], action: 'accept', reason: 'quality')
    expect(AccountCancellation.find(attempt[:id]).outcome).to eq('setup_requested')
    expect(subscriptions_api).not_to have_received(:update)
    entries = Enterprise::Billing::AccountTimelineService.new(account: account).perform
    expect(entries).to include(have_attributes(kind: 'cancellation', title: 'Quality · Setup requested'))
  end

  it 'schedules a smaller plan using the existing downgrade service' do
    attempt = service.start
    changer = instance_double(Enterprise::Billing::AccountPlanChangeService, perform: { status: 'scheduled', effective_at: 20.days.from_now })
    allow(Enterprise::Billing::AccountPlanChangeService).to receive(:new).with(account: account).and_return(changer)
    service.decide(id: attempt[:id], action: 'accept', reason: 'feature', feature: 'Team views', plan: starter)
    expect(changer).to have_received(:perform).with(plan: starter, interval: 'month')
    expect(AccountCancellation.find(attempt[:id])).to have_attributes(outcome: 'downgraded', feature: 'Team views')
  end

  it 'refuses the same plan as a downgrade' do
    attempt = service.start
    expect { service.decide(id: attempt[:id], action: 'accept', reason: 'feature', plan: plan) }.to raise_error(described_class::Unavailable)
  end

  it 'does not offer retention on a pending schedule' do
    remote['schedule'] = 'sub_sched'
    expect(service.start).to include(discount_available: false, pause_available: false, smaller_plans: [])
  end

  it 'allows cancellation of a paused subscription' do
    remote['pause_collection'] = { behavior: 'void', resumes_at: 2.months.from_now.to_i }
    attempt = service.start
    service.decide(id: attempt[:id], action: 'confirm', reason: 'other')
    expect(AccountCancellation.find(attempt[:id]).outcome).to eq('canceled')
  end

  it 'keeps a custom plan scheduled for cancellation' do
    remote.cancel_at_period_end = true
    expect(service.keep).to eq(status: 'kept')
    expect(subscription.reload.stripe_subscription_details['cancel_at_period_end']).to be(false)
  end

  it 'resumes a collection pause and AI access' do
    remote['pause_collection'] = { behavior: 'void', resumes_at: 1.month.from_now.to_i }
    allow(subscriptions_api).to receive(:update) {
      remote['pause_collection'] = nil
      remote
    }
    expect(service.resume).to eq(status: 'resumed')
    expect(subscription.reload.payment_status).to eq('active')
    expect(subscription.ai_reply_allowed?).to be(true)
  end

  it 'refuses another account’s cancellation id' do
    attempt = service.start
    other = create(:account)
    expect { described_class.new(account: other, actor: user).decide(id: attempt[:id], action: 'confirm', reason: 'other') }
      .to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'refuses Stripe resources belonging to another customer' do
    remote.customer = 'cus_other'
    expect { service.start }.to raise_error(described_class::Unavailable)
  end

  it 'refuses Shopify billing' do
    shopify = create(:account, billing_provider: 'shopify')
    expect { described_class.new(account: shopify, actor: user).start }.to raise_error(described_class::Unavailable)
  end

  it 'records keeping a plan after seeing an offer, without changing Stripe' do
    attempt = service.start
    service.dismiss(id: attempt[:id], reason: 'feature', feature: 'Better reports')
    expect(AccountCancellation.find(attempt[:id])).to have_attributes(outcome: 'kept', reason: 'feature', feature: 'Better reports')
    expect(subscriptions_api).not_to have_received(:update)
  end

  it 'does not rewrite a completed discount when the dialog is dismissed' do
    attempt = service.start
    service.decide(id: attempt[:id], action: 'accept', reason: 'expensive')
    service.dismiss(id: attempt[:id], reason: 'other')
    expect(AccountCancellation.find(attempt[:id]).outcome).to eq('discounted')
  end
end
