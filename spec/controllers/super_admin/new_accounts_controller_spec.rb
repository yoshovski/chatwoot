require 'rails_helper'

RSpec.describe 'Super Admin new accounts', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:first_account) { create(:account, name: 'First shop') }
  let(:second_account) { create(:account, name: 'Second shop') }
  let(:quiet_account) { create(:account, name: 'Quiet shop') }

  before do
    AccountSignup.create!(account: first_account, email: 'anna@shop.example', email_domain: 'shop.example', ip: '203.0.113.7', trial_granted: true)
    AccountSignup.create!(account: second_account, email: 'bruno+trial2@gmail.com', website_domain: 'shop.example', ip: '203.0.113.7',
                          trial_refused_reason: 'website_used')
    AccountSignup.create!(account: quiet_account, email: 'carla@other.example', email_domain: 'other.example', ip: '198.51.100.1',
                          trial_granted: true)
  end

  it 'needs a super admin' do
    get '/super_admin/new_accounts'

    expect(response).to have_http_status(:redirect)
    expect(response).not_to redirect_to('/super_admin/new_accounts')
  end

  it 'lists the signups with flags for the same website domain, the same IP and throwaway-looking addresses' do
    sign_in(super_admin, scope: :super_admin)
    get '/super_admin/new_accounts'

    expect(response).to have_http_status(:success)
    expect(response.body).to include('First shop', 'Second shop', 'Quiet shop', I18n.t('super_admin.new_accounts.trial.website_used'))
    rows = Nokogiri::HTML(response.body)
    second_flags = rows.css("[data-test='signup-#{second_account.account_signup.id}'] [data-test^='flag-']").map { |flag| flag['data-test'] }
    expect(second_flags).to contain_exactly('flag-same_domain', 'flag-same_ip', 'flag-disposable_looking')
    expect(rows.css("[data-test='signup-#{quiet_account.account_signup.id}'] [data-test^='flag-']")).to be_empty
  end

  it 'shows only flagged signups on request' do
    sign_in(super_admin, scope: :super_admin)
    get '/super_admin/new_accounts', params: { flagged: '1' }

    expect(response.body).to include('First shop', 'Second shop')
    expect(response.body).not_to include('Quiet shop')
  end
end
