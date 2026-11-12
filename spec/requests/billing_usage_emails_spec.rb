require 'rails_helper'

RSpec.describe 'Billing usage email opt-out' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:account_user) { account.account_users.find_by(user: admin) }
  let(:token) { account_user.signed_id(purpose: :billing_usage_emails) }

  it 'shows the setting without a login' do
    get '/billing_emails/usage_opt_out', params: { token: token }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Stop these emails')
  end

  it 'turns the usage emails off with the one-click POST and back on from the page' do
    post '/billing_emails/usage_opt_out', params: { token: token }
    expect(account_user.reload.billing_usage_emails).to be(false)

    post '/billing_emails/usage_opt_out', params: { token: token, enabled: 'true' }
    expect(account_user.reload.billing_usage_emails).to be(true)
  end

  it 'refuses a token that was not signed for this' do
    post '/billing_emails/usage_opt_out', params: { token: account_user.signed_id(purpose: :other) }

    expect(response).to have_http_status(:not_found)
    expect(account_user.reload.billing_usage_emails).to be(true)
  end
end
