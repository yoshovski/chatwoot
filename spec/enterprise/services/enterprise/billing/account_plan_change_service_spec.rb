require 'rails_helper'

describe Enterprise::Billing::AccountPlanChangeService do
  subject(:service) { described_class.new(account: account) }

  let(:account) { create(:account) }
  let!(:starter) do
    create(:billing_plan, name: 'Starter', monthly_price_cents: 2900).tap do |plan|
      plan.update!(stripe_monthly_price_id: 'price_starter_month', stripe_annual_price_id: 'price_starter_year')
    end
  end
  let!(:growth) do
    create(:billing_plan, name: 'Growth', monthly_price_cents: 7900).tap do |plan|
      plan.update!(stripe_monthly_price_id: 'price_growth_month', stripe_annual_price_id: 'price_growth_year')
    end
  end
  let(:period_start) { 10.days.ago.to_i }
  let(:period_end) { 20.days.from_now.to_i }
  let(:current_price) { 'price_starter_month' }
  let(:schedule) { nil }
  let(:remote) do
    Stripe::Subscription.construct_from(
      id: 'sub_1', object: 'subscription', customer: 'cus_test', metadata: { chatoctave_account_id: account.id.to_s },
      cancel_at_period_end: false, schedule: schedule,
      items: { data: [{ id: 'si_1', quantity: 1, current_period_start: period_start, current_period_end: period_end,
                        price: { id: current_price, recurring: { interval: current_price.end_with?('year') ? 'year' : 'month' } } }] }
    )
  end

  before do
    account.update!(subscription_settings: { billing_plan_id: BillingPlan.for_stripe_price(current_price).id })
    account.account_subscription.update!(stripe_customer_id: 'cus_test', stripe_subscription_id: 'sub_1', payment_status: 'active',
                                         stripe_subscription_details: { interval_change_supported: true, price_id: current_price })
    allow(Enterprise::Billing::AccountSubscriptionSyncService).to receive(:refresh).and_return(remote)
    allow(Stripe::SubscriptionSchedule).to receive(:release)
  end

  context 'when moving to a pricier plan' do
    before do
      allow(Stripe::Subscription).to receive(:update).and_return(Stripe::Subscription.construct_from(id: 'sub_1', pending_update: nil))
    end

    it 'changes the price now with a prorated invoice' do
      expect(service.perform(plan: growth, interval: 'month')).to eq(status: 'changed')

      expect(Stripe::Subscription).to have_received(:update).with(
        'sub_1', hash_including(items: [{ id: 'si_1', price: 'price_growth_month' }], proration_behavior: 'always_invoice',
                                payment_behavior: 'pending_if_incomplete')
      )
    end

    it 'returns the invoice to pay when the card needs confirmation' do
      allow(Stripe::Subscription).to receive(:update).and_return(
        Stripe::Subscription.construct_from(id: 'sub_1', pending_update: { expires_at: 1 },
                                            latest_invoice: { object: 'invoice', hosted_invoice_url: 'https://invoice.stripe.test/1' })
      )

      expect(service.perform(plan: growth, interval: 'month')).to eq(status: 'payment_required', url: 'https://invoice.stripe.test/1')
    end
  end

  it 'treats yearly billing on the same plan as an upgrade' do
    allow(Stripe::Subscription).to receive(:update).and_return(Stripe::Subscription.construct_from(id: 'sub_1'))

    expect(service.perform(plan: starter, interval: 'year')).to eq(status: 'changed')
    expect(Stripe::Subscription).to have_received(:update).with('sub_1', hash_including(items: [{ id: 'si_1', price: 'price_starter_year' }]))
  end

  context 'when moving to a cheaper plan' do
    let(:current_price) { 'price_growth_month' }

    before do
      allow(Stripe::SubscriptionSchedule).to receive(:create).and_return(Stripe::SubscriptionSchedule.construct_from(id: 'sub_sched_1'))
      allow(Stripe::SubscriptionSchedule).to receive(:update)
      allow(Stripe::Subscription).to receive(:update)
    end

    it 'schedules the change for the end of the paid period' do
      result = service.perform(plan: starter, interval: 'month')

      expect(result).to eq(status: 'scheduled', effective_at: Time.zone.at(period_end))
      expect(Stripe::Subscription).not_to have_received(:update)
      expect(Stripe::SubscriptionSchedule).to have_received(:create).with(from_subscription: 'sub_1')
      expect(Stripe::SubscriptionSchedule).to have_received(:update).with(
        'sub_sched_1',
        end_behavior: 'release', proration_behavior: 'none',
        phases: [{ start_date: period_start, end_date: period_end, items: [{ price: 'price_growth_month', quantity: 1 }] },
                 { start_date: period_end, items: [{ price: 'price_starter_month', quantity: 1 }] }]
      )
    end
  end

  context 'when a downgrade is pending' do
    let(:current_price) { 'price_growth_month' }
    let(:schedule) { 'sub_sched_1' }

    it 'drops it when the current plan is chosen again' do
      expect(service.perform(plan: growth, interval: 'month')).to eq(status: 'kept')
      expect(Stripe::SubscriptionSchedule).to have_received(:release).with('sub_sched_1')
    end

    it 'releases it before an upgrade' do
      allow(Stripe::Subscription).to receive(:update).and_return(Stripe::Subscription.construct_from(id: 'sub_1'))

      service.perform(plan: growth, interval: 'year')

      expect(Stripe::SubscriptionSchedule).to have_received(:release).with('sub_sched_1')
      expect(Stripe::Subscription).to have_received(:update).with('sub_1', hash_including(items: [{ id: 'si_1', price: 'price_growth_year' }]))
    end
  end

  it 'refuses a subscription on a custom price' do
    account.account_subscription.update!(stripe_subscription_details: { interval_change_supported: true, price_id: 'price_custom' })

    expect { service.perform(plan: growth, interval: 'month') }.to raise_error do |error|
      expect(error.class.name).to eq('Enterprise::Billing::AccountCheckoutService::Unavailable')
    end
  end
end
