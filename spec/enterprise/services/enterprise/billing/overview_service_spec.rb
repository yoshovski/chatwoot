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
    expect(overview[:ai_cost_status]).to eq('not_connected')
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

    expect(described_class.cached).to include('paying_count' => 0, 'ai_cost_status' => 'not_connected')
  end

  describe 'AI cost from LiteLLM' do
    let!(:subscription) { subscription_for('Acme', payment_status: 'active', monthly_price_cents: 4900) }
    let(:customer) { "chatoctave-account-#{subscription.account_id}" }
    let(:spend_url) { %r{\Ahttp://litellm\.test/customer/daily/activity} }

    around do |example|
      with_modified_env(LITELLM_SPEND_URL: 'http://litellm.test', LITELLM_SPEND_API_KEY: 'sk-viewer') { example.run }
    end

    def day(spend)
      { date: Time.current.to_date.iso8601, breakdown: { entities: { customer => { metrics: { spend: spend } } } } }
    end

    it 'adds the spend since the period started to each account, over every page' do
      first = stub_request(:get, spend_url)
              .with(headers: { 'Authorization' => 'Bearer sk-viewer' },
                    query: hash_including('end_user_ids' => customer, 'page' => '1',
                                          'start_date' => subscription.quota_period.first.utc.to_date.iso8601))
              .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                         body: { results: [day(1.2)], metadata: { has_more: true } }.to_json)
      stub_request(:get, spend_url).with(query: hash_including('page' => '2'))
                                   .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                                              body: { results: [day(0.0345)], metadata: { has_more: false } }.to_json)

      overview = described_class.new.perform

      expect(first).to have_been_requested
      expect(overview[:ai_cost_status]).to eq('connected')
      expect(overview[:accounts].first[:ai_cost_cents]).to eq(123.45)
    end

    it 'says LiteLLM is unavailable and keeps the other numbers' do
      stub_request(:get, spend_url).to_return(status: 401, body: 'nope')

      overview = described_class.new.perform

      expect(overview).to include(ai_cost_status: 'unavailable', paying_count: 1)
      expect(overview[:accounts].first[:ai_cost_cents]).to be_nil
    end
  end
end
