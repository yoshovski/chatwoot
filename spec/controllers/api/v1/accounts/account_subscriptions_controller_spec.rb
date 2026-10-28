require 'rails_helper'

RSpec.describe 'Account subscription API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:plan) do
    create(:billing_plan, name: 'Growth', monthly_price_cents: 4900, ai_conversations_limit: 1000, trial_ai_conversations_limit: 50,
                          inboxes_limit: 2, features: ['captain_integration'], add_ons: { 'disable_branding' => 2000 })
  end

  describe 'GET /api/v1/accounts/{account.id}/account_subscription' do
    it 'returns the plan, per-product usage and daily counts' do
      account.update!(subscription_settings: { billing_plan_id: plan.id, trial_enabled: true })

      get "/api/v1/accounts/#{account.id}/account_subscription", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['plan']).to include('name' => 'Growth', 'monthly_price_cents' => 4900, 'features' => ['captain_integration'])
      expect(body['plan']['add_ons']).to eq([{ 'key' => 'disable_branding', 'price_cents' => 2000, 'active' => false }])
      expect(body['products']['ai_conversations']).to eq('used' => 0, 'limit' => 50, 'period' => 'trial')
      expect(body).to include('trial_enabled' => true)
      expect(body['daily_usage'].last.keys).to include('consumed', 'conversations')
      expect(body).not_to have_key('monthly_price_cents')
    end

    it 'returns usage without a plan' do
      get "/api/v1/accounts/#{account.id}/account_subscription", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('plan' => nil, 'enabled' => false)
      expect(response.parsed_body['products']['ai_conversations']).to include('limit' => nil, 'period' => 'month')
    end
  end
end
