require 'rails_helper'

RSpec.describe EndTrialsJob do
  let(:account) { create(:account, manual_ai_access: false) }
  let(:free) { create(:billing_plan, name: 'Free', ai_conversations_limit: 0, conversations_limit: 100, features: %w[reports]) }
  let(:growth) do
    create(:billing_plan, name: 'Growth', ai_conversations_limit: 150, trial_ai_conversations_limit: 50, after_trial_plan: free,
                          features: %w[reports captain_integration])
  end
  let!(:subscription) { AccountSubscription.create!(account: account, billing_plan: growth, trial_enabled: true) }

  it 'moves an ended unpaid trial to the after-trial plan with AI off' do
    subscription.update!(trial_ends_at: 1.minute.ago)

    described_class.perform_now

    subscription.reload
    expect(subscription).to have_attributes(billing_plan: free, trial_enabled: false, payment_status: 'active')
    expect(subscription.ai_pause_reason).to eq('no_plan')
    expect(account.reload.feature_enabled?('captain_integration')).to be(false)
    expect(account.feature_enabled?('reports')).to be(true)
  end

  it 'moves a trial whose checkout was canceled' do
    subscription.update!(trial_ends_at: 1.minute.ago, payment_status: 'canceled', stripe_subscription_id: 'sub_1')

    described_class.perform_now

    expect(subscription.reload.billing_plan).to eq(free)
  end

  it 'leaves a running trial alone' do
    described_class.perform_now

    expect(subscription.reload).to have_attributes(billing_plan: growth, trial_enabled: true)
  end

  it 'leaves a trial that Stripe runs alone' do
    subscription.update!(trial_ends_at: 1.minute.ago, stripe_subscription_id: 'sub_1')

    described_class.perform_now

    expect(subscription.reload.billing_plan).to eq(growth)
  end

  it 'leaves a paid subscription alone' do
    subscription.update!(trial_ends_at: 1.minute.ago, payment_status: 'active', stripe_subscription_id: 'sub_1')

    described_class.perform_now

    expect(subscription.reload.billing_plan).to eq(growth)
  end

  it 'leaves a plan without an after-trial plan alone' do
    growth.update!(after_trial_plan: nil)
    subscription.update!(trial_ends_at: 1.minute.ago)

    described_class.perform_now

    expect(subscription.reload.billing_plan).to eq(growth)
  end
end
