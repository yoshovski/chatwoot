require 'rails_helper'

describe Enterprise::Billing::AccountSubscriptionSyncService do
  let(:account) { create(:account) }
  let!(:starter) do
    create(:billing_plan, name: 'Starter', monthly_price_cents: 2900, ai_conversations_limit: 300).tap do |plan|
      plan.update!(stripe_monthly_price_id: 'price_starter_month', stripe_annual_price_id: 'price_starter_year')
    end
  end
  let!(:growth) do
    create(:billing_plan, name: 'Growth', monthly_price_cents: 7900, ai_conversations_limit: 1000, features: ['campaigns']).tap do |plan|
      plan.update!(stripe_monthly_price_id: 'price_growth_month', stripe_annual_price_id: 'price_growth_year')
    end
  end
  let(:period_start) { 10.days.ago.to_i }
  let(:period_end) { 20.days.from_now.to_i }
  let(:price_id) { 'price_growth_month' }
  let(:schedule) { nil }
  let(:remote) do
    Stripe::Subscription.construct_from(
      id: 'sub_1', object: 'subscription', customer: 'cus_test', status: 'active', created: 40.days.ago.to_i,
      metadata: { chatoctave_account_id: account.id.to_s }, cancel_at_period_end: false, collection_method: 'charge_automatically',
      schedule: schedule, trial_end: nil,
      items: { data: [{ id: 'si_1', quantity: 1, current_period_start: period_start, current_period_end: period_end,
                        price: { id: price_id, unit_amount: 7900, currency: 'eur', billing_scheme: 'per_unit',
                                 recurring: { interval: 'month', interval_count: 1, usage_type: 'licensed' } } }] }
    )
  end
  let(:subscription) { account.account_subscription }

  before do
    account.update!(subscription_settings: { billing_plan_id: starter.id })
    subscription.update!(stripe_customer_id: 'cus_test', stripe_subscription_id: 'sub_1', payment_status: 'active',
                         quota_anchor: 40.days.ago)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(remote)
  end

  it 'moves the account to the plan of its Stripe price, with its features' do
    described_class.refresh(account)

    expect(subscription.reload.billing_plan).to eq(growth)
    expect(subscription.stripe_subscription_details).to include('price_id' => 'price_growth_month', 'pending_change' => nil)
    expect(subscription.plan_change_available?).to be(true)
    expect(account.reload.feature_enabled?('campaigns')).to be(true)
  end

  it 'starts a new AI allowance on the change date and keeps the earlier usage in the history' do
    before_change = subscription.quota_period.first
    account.conversation_usage_windows.create!(started_at: 1.day.ago, ends_at: Time.current, quota_period_start: before_change)
    expect(subscription.consumed).to eq(1)

    freeze_time do
      described_class.refresh(account)

      expect(subscription.reload.quota_anchor).to eq(Time.current)
      expect(subscription.consumed).to eq(0)
      expect(subscription.usage_summary).to include(monthly_limit: 1000, quota_started_at: Time.current)
      expect(subscription.usage_history).to include(period_started_at: before_change, consumed: 1)
    end
  end

  it 'keeps the card brand and last four digits for the Billing page' do
    remote['default_payment_method'] = Stripe::PaymentMethod.construct_from(id: 'pm_1', object: 'payment_method', type: 'card',
                                                                             card: { brand: 'visa', last4: '4242' })

    described_class.refresh(account)

    expect(subscription.reload.stripe_subscription_details['card']).to eq('brand' => 'visa', 'last4' => '4242')
  end

  it 'keeps the allowance when the plan does not change' do
    anchor = subscription.quota_anchor
    subscription.update!(billing_plan: growth)

    described_class.refresh(account)

    expect(subscription.reload.quota_anchor).to eq(anchor)
  end

  context 'with a downgrade scheduled for the period end' do
    let(:schedule) do
      { id: 'sub_sched_1', object: 'subscription_schedule', current_phase: { start_date: period_start, end_date: period_end },
        phases: [{ start_date: period_start, end_date: period_end, items: [{ price: 'price_growth_month', quantity: 1 }] },
                 { start_date: period_end, end_date: nil, items: [{ price: 'price_starter_year', quantity: 1 }] }] }
    end

    it 'shows the pending change' do
      described_class.refresh(account)

      expect(subscription.reload.stripe_subscription_details).to include(
        'schedule' => 'sub_sched_1',
        'pending_change' => { 'plan_id' => starter.id, 'plan_name' => 'Starter', 'interval' => 'year',
                              'effective_at' => Time.zone.at(period_end).iso8601 }
      )
      expect(subscription.pricing_summary[:pending_plan_change]).to include('plan_name' => 'Starter')
    end

    it 'clears it once the new phase has started' do
      remote['schedule']['current_phase'] = Stripe::StripeObject.construct_from(start_date: period_end, end_date: period_end + 30.days.to_i)

      described_class.refresh(account)

      expect(subscription.reload.stripe_subscription_details['pending_change']).to be_nil
    end
  end

  it 'applies the new plan features after an upgrade through the plan change service' do
    starter_remote = Stripe::Subscription.construct_from(remote.to_hash.deep_merge(items: { data: [remote.items.data.first.to_hash.merge(
      price: remote.items.data.first.price.to_hash.merge(id: 'price_starter_month', unit_amount: 2900)
    )] }))
    allow(Stripe::Subscription).to receive(:retrieve).and_return(starter_remote, starter_remote, remote)
    allow(Stripe::Subscription).to receive(:update).and_return(Stripe::Subscription.construct_from(id: 'sub_1'))
    described_class.refresh(account)
    expect(account.reload.feature_enabled?('campaigns')).to be(false)

    Enterprise::Billing::AccountPlanChangeService.new(account: account).perform(plan: growth, interval: 'month')

    expect(subscription.reload.billing_plan).to eq(growth)
    expect(account.reload.feature_enabled?('campaigns')).to be(true)
  end
end
