require 'rails_helper'

RSpec.describe 'Super Admin billing plans', type: :request do
  let(:super_admin) { create(:super_admin) }

  before { sign_in(super_admin, scope: :super_admin) }

  it 'lists plans' do
    plan = create(:billing_plan, name: 'Growth')

    get '/super_admin/billing_plans'

    expect(response).to have_http_status(:success)
    expect(response.body).to include(plan.name)
  end

  it 'renders the plan form with every plan feature' do
    get '/super_admin/billing_plans/new'

    expect(response).to have_http_status(:success)
    expect(response.body).to include('billing_plan[feature_settings][captain_integration]')
  end

  it 'creates a plan with limits, included features and add-ons' do
    post '/super_admin/billing_plans', params: {
      billing_plan: {
        name: 'Starter', currency: 'eur', monthly_price: '29,00', trial_days: 14, ai_conversations_limit: 300,
        trial_ai_conversations_limit: 50, agents_limit: 3,
        feature_settings: { captain_integration: 'included', disable_branding: 'add_on', campaigns: '' },
        add_on_prices: { disable_branding: '20' }
      }
    }

    plan = BillingPlan.find_by!(name: 'Starter')
    expect(plan).to have_attributes(monthly_price_cents: 2900, ai_conversations_limit: 300, trial_ai_conversations_limit: 50,
                                    agents_limit: 3, features: ['captain_integration'], add_ons: { 'disable_branding' => 2000 })
  end

  it 'assigns a plan and add-ons to an account from the account form' do
    plan = create(:billing_plan, features: ['captain_integration'], add_ons: { 'help_center' => 1000 })
    account = create(:account)

    patch "/super_admin/accounts/#{account.id}", params: {
      account: { name: account.name, subscription_settings: { billing_plan_id: plan.id, add_ons: ['', 'help_center'] } }
    }

    subscription = account.reload.account_subscription
    expect(subscription).to have_attributes(billing_plan_id: plan.id, add_ons: ['help_center'], enabled: true)
    expect(account.feature_enabled?('help_center')).to be(true)
  end
end
