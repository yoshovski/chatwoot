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

  describe 'GET /api/v1/accounts/{account.id}/integrations/hubspot/contact' do
    let(:contact) { create(:contact, account: account, email: 'jane@example.com') }
    let(:search_url) { 'https://api.hubapi.com/crm/v3/objects/contacts/search' }
    let(:record) do
      { id: '901', properties: { firstname: 'Jane', lastname: 'Doe', email: 'jane@example.com', phone: '+15550100',
                                 lifecyclestage: 'marketingqualifiedlead', hs_lead_status: 'NEW', hubspot_owner_id: '77',
                                 createdate: '2026-01-01T10:00:00Z', lastmodifieddate: '2026-01-02T10:00:00Z' } }
    end
    let(:json_headers) { { 'Content-Type' => 'application/json' } }

    before do
      stub_request(:get, 'https://api.hubapi.com/crm/v3/properties/contacts/lifecyclestage')
        .to_return(status: 200, body: { options: [{ value: 'marketingqualifiedlead', label: 'Marketing Qualified Lead' }] }.to_json,
                   headers: json_headers)
      stub_request(:get, 'https://api.hubapi.com/crm/v3/properties/contacts/hs_lead_status')
        .to_return(status: 200, body: { options: [{ value: 'NEW', label: 'New' }] }.to_json, headers: json_headers)
    end

    it 'finds the contact by email for agents and returns the card' do
      stub_request(:post, search_url)
        .with { |request| JSON.parse(request.body)['filterGroups'][0]['filters'][0]['value'] == 'jane@example.com' }
        .to_return(status: 200, body: { results: [record] }.to_json, headers: json_headers)

      get "#{base_url}/contact", headers: agent.create_new_auth_token, params: { contact_id: contact.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'found' => true, 'id' => '901', 'url' => 'https://app.hubspot.com/contacts/12345/record/0-1/901',
        'name' => 'Jane Doe', 'email' => 'jane@example.com', 'phone' => '+15550100',
        'lifecyclestage' => 'Marketing Qualified Lead', 'hs_lead_status' => 'New', 'owner_name' => nil,
        'createdate' => '2026-01-01T10:00:00Z', 'lastmodifieddate' => '2026-01-02T10:00:00Z'
      )
    end

    it 'uses the stored HubSpot id, the owner when that scope was granted and the EU domain for EU portals' do
      hook.update!(settings: hook.settings.merge('scopes' => hook.settings['scopes'] + ['crm.objects.owners.read'],
                                                 'refresh_token' => 'eu1-refresh-token'))
      contact.update!(additional_attributes: { 'external' => { 'hubspot_id' => '901' } })
      stub_request(:get, %r{https://api.hubapi.com/crm/v3/objects/contacts/901\?properties=})
        .to_return(status: 200, body: record.to_json, headers: json_headers)
      stub_request(:get, 'https://api.hubapi.com/crm/v3/owners/77')
        .to_return(status: 200, body: { firstName: 'Sam', lastName: 'Owner' }.to_json, headers: json_headers)

      get "#{base_url}/contact", headers: agent.create_new_auth_token, params: { contact_id: contact.id }

      expect(response.parsed_body).to include('owner_name' => 'Sam Owner', 'url' => 'https://app-eu1.hubspot.com/contacts/12345/record/0-1/901')
      expect(a_request(:post, search_url)).not_to have_been_made
    end

    it 'returns found false when HubSpot has no matching contact' do
      contact.update!(additional_attributes: { 'external' => { 'hubspot_id' => '404' } })
      stub_request(:get, %r{https://api.hubapi.com/crm/v3/objects/contacts/404}).to_return(status: 404)
      stub_request(:post, search_url).to_return(status: 200, body: { results: [] }.to_json, headers: json_headers)

      get "#{base_url}/contact", headers: agent.create_new_auth_token, params: { contact_id: contact.id }

      expect(response.parsed_body).to eq('found' => false)
    end

    it 'asks to reauthorize on token errors and when the hook is disabled' do
      stub_request(:post, search_url).to_return(status: 403)

      get "#{base_url}/contact", headers: agent.create_new_auth_token, params: { contact_id: contact.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('error' => 'reauthorize')

      hook.update!(status: :disabled)
      get "#{base_url}/contact", headers: agent.create_new_auth_token, params: { contact_id: contact.id }
      expect(response.parsed_body).to eq('error' => 'reauthorize')
    end

    it 'reports HubSpot outages without failing' do
      stub_request(:post, search_url).to_return(status: 503)

      get "#{base_url}/contact", headers: agent.create_new_auth_token, params: { contact_id: contact.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('error' => 'unavailable')
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
