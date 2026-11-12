require 'rails_helper'

RSpec.describe 'Account subscription API: Stripe plans and top-ups', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:plan) do
    create(:billing_plan, name: 'Growth', monthly_price_cents: 4900, ai_conversations_limit: 1000, trial_ai_conversations_limit: 50,
                          inboxes_limit: 2, features: ['captain_integration'], add_ons: { 'disable_branding' => 2000 })
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

  describe 'top-ups (T07)' do
    let(:admin) { create(:user, account: account, role: :administrator) }
    let(:top_up) { instance_double(Enterprise::Billing::TopUpService, buy: { status: 'paid' }) }
    let(:subscription) { account.account_subscription }

    before do
      account.update!(subscription_settings: { billing_plan_id: plan.id, enabled: true })
      subscription.update!(stripe_customer_id: 'cus_top', stripe_subscription_id: 'sub_top', payment_status: 'active')
      allow(Enterprise::Billing::TopUpService).to receive(:new).and_return(top_up)
    end

    it 'starts a pack payment with the click id' do
      post "/api/v1/accounts/#{account.id}/account_subscription/top_up", params: { request_id: 'click-0001' },
                                                                         headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('status' => 'paid')
      expect(top_up).to have_received(:buy).with(request_id: 'click-0001')
    end

    it 'says when the card is declined' do
      allow(top_up).to receive(:buy).and_raise(Enterprise::Billing::TopUpService::PaymentFailed)

      post "/api/v1/accounts/#{account.id}/account_subscription/top_up", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'saves the auto top-up settings and clears an earlier failure' do
      subscription.update!(auto_top_up_failed_at: 1.day.ago)

      patch "/api/v1/accounts/#{account.id}/account_subscription/top_up_settings",
            params: { auto_top_up_enabled: true, auto_top_up_max_packs: 3 }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['auto']).to include('enabled' => true, 'max_packs' => 3, 'failed_at' => nil)
    end

    it 'keeps the ceiling between 1 and 10 packs' do
      patch "/api/v1/accounts/#{account.id}/account_subscription/top_up_settings",
            params: { auto_top_up_enabled: true, auto_top_up_max_packs: 11 }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(subscription.reload.auto_top_up_enabled).to be(false)
    end

    it 'lets only administrators buy' do
      post "/api/v1/accounts/#{account.id}/account_subscription/top_up", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(top_up).not_to have_received(:buy)
    end

    it 'shows the pack, the auto top-up settings and the history to administrators' do
      ExtraAiConversationEntry.credit!(account: account, amount: 50, stripe_reference: 'in_pack')

      get "/api/v1/accounts/#{account.id}/account_subscription", headers: admin.create_new_auth_token, as: :json

      top_up_json = response.parsed_body['top_up']
      expect(top_up_json).to include('available' => true, 'pack' => { 'conversations' => 50, 'amount_cents' => 800, 'currency' => 'eur' })
      expect(top_up_json['history']).to contain_exactly(include('reason' => 'purchase', 'amount' => 50))
    end
  end
end
