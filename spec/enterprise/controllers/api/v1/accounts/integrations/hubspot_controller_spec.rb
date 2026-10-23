require 'rails_helper'

RSpec.describe 'HubSpot Integration API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:hook) { create(:integrations_hook, :hubspot, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/integrations/hubspot" }

  let(:properties_url) { 'https://api.hubapi.com/crm/v3/properties/contacts' }
  let(:portal_properties) do
    [
      { name: 'email', label: 'Email', type: 'string', fieldType: 'text', groupName: 'contactinformation' },
      { name: 'firstname', label: 'First Name', type: 'string', fieldType: 'text', groupName: 'contactinformation' },
      { name: 'lastname', label: 'Last Name', type: 'string', fieldType: 'text', groupName: 'contactinformation' },
      { name: 'phone', label: 'Phone Number', type: 'string', fieldType: 'phonenumber', groupName: 'contactinformation' },
      { name: 'chatoctave_lead_type', label: 'Lead type', type: 'string', fieldType: 'text', groupName: 'chatoctave' },
      { name: 'hs_object_id', label: 'Record ID', type: 'number', fieldType: 'number', groupName: 'contactinformation',
        modificationMetadata: { readOnlyValue: true } }
    ]
  end

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return('test-client-id')
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_SECRET', nil).and_return('test-client-secret')
    stub_request(:get, properties_url).to_return(status: 200, body: { results: portal_properties }.to_json,
                                                 headers: { 'Content-Type' => 'application/json' })
  end

  describe 'GET /api/v1/accounts/{account.id}/integrations/hubspot/properties' do
    it 'returns unauthorized for agents' do
      get "#{base_url}/properties", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns writable portal properties and the mappable contact fields' do
      create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute',
                                           attribute_key: 'plan', attribute_display_name: 'Plan')

      get "#{base_url}/properties", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      properties = response.parsed_body['properties']
      expect(properties.pluck('name')).to eq(%w[email firstname lastname phone chatoctave_lead_type])
      expect(properties.first).to eq('name' => 'email', 'label' => 'Email', 'type' => 'string', 'fieldType' => 'text',
                                     'groupName' => 'contactinformation')
      expect(response.parsed_body['sources'].pluck('key')).to include('email', 'phone', 'lead_type', 'lead_source', 'plan')
    end

    it 'asks to reauthorize when HubSpot rejects the token' do
      stub_request(:get, properties_url).to_return(status: 403)

      get "#{base_url}/properties", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('reauthorize')
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/integrations/hubspot' do
    let(:mapping) { { email: 'email', firstname: 'firstname', phone: 'phone', lead_type: 'chatoctave_lead_type' } }

    it 'returns unauthorized for agents' do
      patch base_url, headers: agent.create_new_auth_token, params: { settings: { field_mapping: mapping } }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'saves the mapping and toggles' do
      patch base_url, headers: administrator.create_new_auth_token,
                      params: { settings: { field_mapping: mapping, sync_contacts: false, save_transcripts: false } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(hook.reload.settings).to include('field_mapping' => mapping.stringify_keys, 'sync_contacts' => false,
                                              'save_transcripts' => false, 'refresh_token' => 'na1-refresh-token')
      expect(response.parsed_body['settings']).not_to have_key('refresh_token')
    end

    it 'rejects properties that do not exist or are read-only' do
      patch base_url, headers: administrator.create_new_auth_token,
                      params: { settings: { field_mapping: mapping.merge(lastname: 'hs_object_id') } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('hs_object_id')
      expect(hook.reload.settings['field_mapping']['lastname']).to eq('lastname')
    end

    it 'rejects a HubSpot property mapped twice' do
      patch base_url, headers: administrator.create_new_auth_token,
                      params: { settings: { field_mapping: mapping.merge(lastname: 'firstname') } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects unknown contact fields and a remapped email' do
      patch base_url, headers: administrator.create_new_auth_token,
                      params: { settings: { field_mapping: mapping.merge(unknown_field: 'lastname') } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      patch base_url, headers: administrator.create_new_auth_token,
                      params: { settings: { field_mapping: mapping.merge(email: 'firstname') } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects non-boolean toggles' do
      patch base_url, headers: administrator.create_new_auth_token,
                      params: { settings: { field_mapping: mapping, sync_contacts: 'yes' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
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
