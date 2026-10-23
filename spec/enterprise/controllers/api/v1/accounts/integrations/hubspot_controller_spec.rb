require 'rails_helper'

RSpec.describe 'HubSpot Integration API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:hook) { create(:integrations_hook, :hubspot, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/integrations/hubspot" }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return('test-client-id')
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_SECRET', nil).and_return('test-client-secret')
  end

  describe 'DELETE /api/v1/accounts/{account.id}/integrations/hubspot' do
    let(:revoke_url) { 'https://api.hubapi.com/oauth/2026-03/token/revoke' }

    it 'returns unauthorized for agents' do
      delete base_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Integrations::Hook.exists?(hook.id)).to be(true)
    end

    it 'revokes the refresh token and deletes the hook' do
      revoke = stub_request(:post, revoke_url).with(body: hash_including('token' => 'na1-refresh-token')).to_return(status: 200)

      delete base_url, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(revoke).to have_been_requested
      expect(Integrations::Hook.exists?(hook.id)).to be(false)
    end

    it 'still deletes the hook when the revocation fails' do
      stub_request(:post, revoke_url).to_return(status: 500)

      delete base_url, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(Integrations::Hook.exists?(hook.id)).to be(false)
    end
  end
end
