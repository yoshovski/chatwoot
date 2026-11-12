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
      expect(body['products']['ai_conversations']).to eq('used' => 0, 'limit' => 50, 'period' => 'trial', 'extra_left' => 0)
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

  describe 'plans linked to Stripe' do
    let(:admin) { create(:user, account: account, role: :administrator) }
    let(:checkout) { instance_double(Enterprise::Billing::AccountCheckoutService, checkout: { url: 'https://checkout.stripe.test' }) }
    let(:plan_change) { instance_double(Enterprise::Billing::AccountPlanChangeService, perform: { status: 'changed' }) }

    before do
      plan.update!(stripe_monthly_price_id: 'price_growth_month', stripe_annual_price_id: 'price_growth_year')
      allow(Enterprise::Billing::AccountCheckoutService).to receive(:new).and_return(checkout)
      allow(Enterprise::Billing::AccountPlanChangeService).to receive(:new).and_return(plan_change)
    end

    it 'lists the plans an admin can buy, yearly at ten months' do
      account.update!(subscription_settings: { billing_plan_id: plan.id, trial_enabled: true })

      get "/api/v1/accounts/#{account.id}/account_subscription", headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['plans']).to contain_exactly(include('id' => plan.id, 'monthly_price_cents' => 4900, 'annual_price_cents' => 49_000))
      expect(body).to include('can_buy_plan' => true, 'can_change_plan' => false, 'pending_plan_change' => nil)
    end

    it 'starts Checkout for the chosen plan and interval' do
      post "/api/v1/accounts/#{account.id}/account_subscription/checkout", params: { plan_id: plan.id, interval: 'year' },
                                                                           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(checkout).to have_received(:checkout).with(interval: 'year', plan: plan)
    end

    it 'rejects an unknown plan' do
      post "/api/v1/accounts/#{account.id}/account_subscription/checkout", params: { plan_id: 0, interval: 'month' },
                                                                           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'changes the plan' do
      post "/api/v1/accounts/#{account.id}/account_subscription/change_plan", params: { plan_id: plan.id, interval: 'month' },
                                                                              headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('status' => 'changed')
      expect(plan_change).to have_received(:perform).with(plan: plan, interval: 'month')
    end

    it 'does not let an agent change the plan' do
      post "/api/v1/accounts/#{account.id}/account_subscription/change_plan", params: { plan_id: plan.id, interval: 'month' },
                                                                              headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(plan_change).not_to have_received(:perform)
    end
  end
end
