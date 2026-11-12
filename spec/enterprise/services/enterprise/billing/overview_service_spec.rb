require 'rails_helper'

RSpec.describe Enterprise::Billing::OverviewService do
  let(:plan) { create(:billing_plan, name: 'Growth', ai_conversations_limit: 10, monthly_price_cents: 4900) }

  def subscription_for(name, **attributes)
    account = create(:account, name: name, manual_ai_access: false)
    AccountSubscription.create!({ account: account, billing_plan: plan, enabled: true, quota_anchor: 1.day.ago }.merge(attributes))
  end

  def stripe_event(type, customer, object, at: Time.current)
    StripeEvent.create!(stripe_id: "evt_#{SecureRandom.hex(4)}", event_type: type, stripe_customer_id: customer, stripe_created_at: at,
                        payload: { data: { object: object } })
  end

  it 'computes MRR, paying accounts, trials, past due and accounts near the limit from the database only' do
    paying = subscription_for('Yearly', payment_status: 'active', stripe_subscription_id: 'sub_y', stripe_customer_id: 'cus_y',
                                        stripe_subscription_details: { amount_cents: 48_000, currency: 'eur', quantity: 1, interval: 'year' })
    late = subscription_for('Late', payment_status: 'past_due', monthly_price_cents: 4900, payment_failed_at: 2.days.ago)
    subscription_for('Trial', payment_status: 'trialing', trial_enabled: true, trial_ends_at: 3.days.from_now)
    subscription_for('Long trial', payment_status: 'trialing', trial_enabled: true, trial_ends_at: 20.days.from_now)
    subscription_for('Free', payment_status: 'active', monthly_price_cents: 0)
    8.times do |i|
      ConversationUsageWindow.create!(account: late.account, quota_period_start: late.quota_period.first, started_at: i.minutes.ago,
                                      ends_at: 1.day.from_now)
    end

    overview = described_class.new.perform

    expect(overview).to include(mrr_cents: { 'eur' => 4000 + 4900 }, paying_count: 2, trials_count: 2)
    expect(overview[:trials_ending].pluck(:name)).to eq(['Trial'])
    expect(overview[:past_due].pluck(:account_id)).to eq([late.account_id])
    expect(overview[:near_limit].pluck(:account_id)).to eq([late.account_id])
    expect(overview[:accounts].find { |row| row[:account_id] == paying.account_id }).to include(revenue_cents: 4000, ai_cost_cents: nil)
    expect(overview[:ai_cost_connected]).to be(false)
  end

  it 'lists cancellations this month with their reasons and drops one the customer took back' do
    ended = subscription_for('Gone', payment_status: 'canceled', stripe_customer_id: 'cus_gone')
    subscription_for('Back', payment_status: 'active', stripe_customer_id: 'cus_back')
    stripe_event('customer.subscription.deleted', 'cus_gone',
                 { id: 'sub_gone', cancellation_details: { reason: 'cancellation_requested', feedback: 'too_expensive', comment: 'Pricey' } })
    stripe_event('customer.subscription.updated', 'cus_back', { id: 'sub_back', cancel_at_period_end: true }, at: 2.minutes.ago)
    stripe_event('customer.subscription.updated', 'cus_back', { id: 'sub_back', cancel_at_period_end: false }, at: 1.minute.ago)
    stripe_event('customer.subscription.deleted', 'cus_gone', { id: 'sub_old' }, at: 2.months.ago)

    cancellations = described_class.new.perform[:cancellations]

    expect(cancellations.size).to eq(1)
    expect(cancellations.first).to include(account_id: ended.account_id, state: 'ended', feedback: 'too_expensive', comment: 'Pricey')
  end

  it 'keeps the result in Redis for the page' do
    Redis::Alfred.delete(described_class::REDIS_KEY)
    expect(described_class.cached).to be_nil

    Enterprise::Billing::OverviewSnapshotJob.perform_now

    expect(described_class.cached).to include('paying_count' => 0, 'ai_cost_connected' => false)
  end
end
