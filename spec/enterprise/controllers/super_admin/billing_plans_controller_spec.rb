require 'rails_helper'

RSpec.describe 'Super Admin billing plans: Stripe prices', type: :request do
  let(:super_admin) { create(:super_admin) }

  before { sign_in(super_admin, scope: :super_admin) }

  it 'creates the Stripe prices of a plan from its page' do
    plan = create(:billing_plan, name: 'Starter', monthly_price_cents: 2900)
    service = instance_double(Enterprise::Billing::PlanStripePricesService, perform: true)
    allow(Enterprise::Billing::PlanStripePricesService).to receive(:new).with(plan: plan).and_return(service)

    get "/super_admin/billing_plans/#{plan.id}"
    expect(response.body).to include(I18n.t('super_admin.billing_plan.create_stripe_prices'))

    post "/super_admin/billing_plans/#{plan.id}/create_stripe_prices"

    expect(service).to have_received(:perform)
    expect(response).to redirect_to("/super_admin/billing_plans/#{plan.id}")
  end
end
