require 'rails_helper'

RSpec.describe Crm::Hubspot::Client do
  let(:hook) { create(:integrations_hook, :hubspot) }
  let(:client) { described_class.new(hook) }
  let(:properties_url) { 'https://api.hubapi.com/crm/v3/properties/contacts' }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return('test-client-id')
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_SECRET', nil).and_return('test-client-secret')
  end

  it 'sends the hook access token' do
    stub_request(:get, properties_url).with(headers: { 'Authorization' => 'Bearer hubspot-access-token' })
                                      .to_return(status: 200, body: { results: [{ name: 'email' }] }.to_json,
                                                 headers: { 'Content-Type' => 'application/json' })

    expect(client.properties).to eq([{ 'name' => 'email' }])
  end

  it 'refreshes the token once and retries after a 401' do
    stub_request(:get, properties_url).with(headers: { 'Authorization' => 'Bearer hubspot-access-token' }).to_return(status: 401)
    stub_request(:get, properties_url).with(headers: { 'Authorization' => 'Bearer fresh-token' })
                                      .to_return(status: 200, body: { results: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, 'https://api.hubapi.com/oauth/2026-03/token')
      .to_return(status: 200, body: { access_token: 'fresh-token', expires_in: 1800 }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(client.properties).to eq([])
  end

  it 'raises an authorization error when the retry is also rejected' do
    stub_request(:get, properties_url).to_return(status: 401)
    stub_request(:post, 'https://api.hubapi.com/oauth/2026-03/token')
      .to_return(status: 200, body: { access_token: 'fresh-token', expires_in: 1800 }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect { client.properties }.to raise_error(Crm::Hubspot::Client::AuthorizationError)
  end

  it 'does not include the response body in errors' do
    stub_request(:get, properties_url).to_return(status: 500, body: { message: 'jane@example.com' }.to_json)

    expect { client.properties }.to raise_error(Crm::Hubspot::Client::ApiError, 'HubSpot request failed (HTTP 500)')
  end
end
