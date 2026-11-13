require 'rails_helper'

RSpec.describe 'First-week email opt-out' do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :administrator) }
  let(:account_user) { account.account_users.find_by(user: owner) }
  let(:token) { account_user.signed_id(purpose: :onboarding_emails) }

  it 'shows the setting without a login' do
    get '/onboarding_emails/opt_out', params: { token: token }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Stop these emails')
  end

  it 'turns the emails off with the one-click POST and back on from the page' do
    post '/onboarding_emails/opt_out', params: { token: token }
    expect(account_user.reload.onboarding_emails).to be(false)

    post '/onboarding_emails/opt_out', params: { token: token, enabled: 'true' }
    expect(account_user.reload.onboarding_emails).to be(true)
  end

  it 'rejects a token for another purpose' do
    get '/onboarding_emails/opt_out', params: { token: account_user.signed_id(purpose: :billing_usage_emails) }

    expect(response).to have_http_status(:not_found)
  end
end
