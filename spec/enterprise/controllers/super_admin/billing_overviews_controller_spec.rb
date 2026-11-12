require 'rails_helper'

RSpec.describe 'Super Admin billing overview', type: :request do
  let(:super_admin) { create(:super_admin) }

  before do
    Redis::Alfred.delete(Enterprise::Billing::OverviewService::REDIS_KEY)
    sign_in(super_admin, scope: :super_admin)
  end

  it 'asks to log in first' do
    sign_out(:super_admin)
    get '/super_admin/billing_overview'
    expect(response).to have_http_status(:redirect)
  end

  it 'says the numbers are not computed yet' do
    get '/super_admin/billing_overview'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('super_admin.billing_overview.empty'))
  end

  it 'shows the stored numbers without computing them or calling Stripe' do
    account = create(:account, name: 'Acme', manual_ai_access: false)
    AccountSubscription.create!(account: account, enabled: true, payment_status: 'past_due', monthly_price_cents: 4900, quota_anchor: 1.day.ago)
    Enterprise::Billing::OverviewService.store!
    allow(Enterprise::Billing::OverviewService).to receive(:new).and_call_original
    allow(Stripe::Subscription).to receive(:retrieve)

    get '/super_admin/billing_overview'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('49.00 EUR', 'Acme', I18n.t('super_admin.billing_overview.ai_cost_not_connected'))
    expect(Enterprise::Billing::OverviewService).not_to have_received(:new)
    expect(Stripe::Subscription).not_to have_received(:retrieve)
  end

  it 'queues a refresh' do
    expect { post '/super_admin/billing_overview/refresh' }.to have_enqueued_job(Enterprise::Billing::OverviewSnapshotJob)
    expect(response).to redirect_to('/super_admin/billing_overview')
  end
end
