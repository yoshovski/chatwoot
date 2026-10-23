require 'rails_helper'

RSpec.describe 'HubSpot Authorization API', type: :request do
  let(:account) { create(:account) }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return('test-client-id')
  end

  describe 'POST /api/v1/accounts/{account.id}/hubspot/authorization' do
    it 'returns unauthorized for agents' do
      agent = create(:user, account: account, role: :agent)

      post "/api/v1/accounts/#{account.id}/hubspot/authorization", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the HubSpot authorize url with a signed account state' do
      administrator = create(:user, account: account, role: :administrator)

      post "/api/v1/accounts/#{account.id}/hubspot/authorization", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      url = response.parsed_body['url']
      params = CGI.parse(URI.parse(url).query)
      expect(url).to start_with('https://app.hubspot.com/oauth/authorize')
      expect(params['client_id']).to eq(['test-client-id'])
      expect(params['redirect_uri']).to eq(["#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/hubspot/callback"])
      expect(params['scope']).to eq(['oauth crm.objects.contacts.read crm.objects.contacts.write crm.schemas.contacts.read'])
      expect(params['optional_scope']).to eq(['crm.objects.owners.read'])
      expect(GlobalID::Locator.locate_signed(params['state'].first, for: 'default')).to eq(account)
    end
  end
end
