require 'rails_helper'

RSpec.describe BillingPlan do
  let(:account) { create(:account) }

  describe 'feature settings from the Super Admin form' do
    it 'splits features into included ones and priced add-ons' do
      plan = create(:billing_plan, feature_settings: { 'captain_integration' => 'included', 'help_center' => 'add_on', 'campaigns' => '' },
                                   add_on_prices: { 'help_center' => '10,50' })

      expect(plan.features).to eq(['captain_integration'])
      expect(plan.add_ons).to eq('help_center' => 1050)
      expect(plan.feature_setting('help_center')).to eq('add_on')
    end

    it 'rejects features that plans do not govern' do
      expect(build(:billing_plan, features: ['inbound_emails'])).not_to be_valid
    end
  end

  describe 'feature flags on assigned accounts' do
    let(:plan) { create(:billing_plan, features: ['captain_integration'], add_ons: { 'help_center' => 1000, 'disable_branding' => 2000 }) }

    before { account.enable_features!('campaigns') }

    it 'sets plan features and bought add-ons when an account gets the plan' do
      account.update!(subscription_settings: { billing_plan_id: plan.id, add_ons: ['help_center'] })

      account.reload
      expect(account.feature_enabled?('captain_integration')).to be(true)
      expect(account.feature_enabled?('help_center')).to be(true)
      expect(account.feature_enabled?('disable_branding')).to be(false)
      expect(account.feature_enabled?('campaigns')).to be(false)
      expect(account.subscription_settings).to be_enabled
    end

    it 'updates assigned accounts when the plan changes' do
      account.update!(subscription_settings: { billing_plan_id: plan.id })

      plan.update!(features: %w[captain_integration campaigns])

      expect(account.reload.feature_enabled?('campaigns')).to be(true)
    end

    it 'leaves accounts without a plan alone' do
      plan.update!(features: [])

      expect(account.reload.feature_enabled?('campaigns')).to be(true)
    end
  end
end
