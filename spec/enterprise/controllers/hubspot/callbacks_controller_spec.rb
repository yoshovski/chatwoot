require 'rails_helper'

RSpec.describe Hubspot::CallbacksController, type: :request do
  let(:account) { create(:account) }
  let(:state) { account.to_sgid(expires_in: 15.minutes, for: 'default').to_s }
  let(:frontend_url) { 'http://www.example.com' }
  let(:integration_url) { "#{frontend_url}/app/accounts/#{account.id}/settings/integrations/hubspot" }
  let(:token_body) { { access_token: 'new-access-token', refresh_token: 'na1-new-refresh-token', expires_in: 1800 } }
  let(:introspect_body) do
    { active: true, hub_id: 12_345, hub_domain: 'example-portal.hubspot.com', user: 'admin@example.com',
      scopes: %w[oauth crm.objects.contacts.read] }
  end

  around do |example|
    with_modified_env(FRONTEND_URL: frontend_url) { example.run }
  end

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return('test-client-id')
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_SECRET', nil).and_return('test-client-secret')
    stub_request(:post, 'https://api.hubapi.com/oauth/2026-03/token')
      .with(body: hash_including('grant_type' => 'authorization_code', 'code' => 'auth-code', 'client_id' => 'test-client-id',
                                 'client_secret' => 'test-client-secret', 'redirect_uri' => "#{frontend_url}/hubspot/callback"))
      .to_return(status: 200, body: token_body.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, 'https://api.hubapi.com/oauth/2026-03/token/introspect')
      .with(body: hash_including('token' => 'new-access-token'))
      .to_return(status: 200, body: introspect_body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'creates an enabled hook with the tokens, portal details and default settings' do
    get '/hubspot/callback', params: { code: 'auth-code', state: state }

    expect(response).to redirect_to(integration_url)
    hook = account.hooks.find_by!(app_id: 'hubspot')
    expect(hook).to be_enabled
    expect(hook.access_token).to eq('new-access-token')
    expect(hook.settings).to include(
      'refresh_token' => 'na1-new-refresh-token', 'portal_id' => 12_345, 'hub_domain' => 'example-portal.hubspot.com',
      'user' => 'admin@example.com', 'sync_contacts' => true, 'save_transcripts' => true,
      'field_mapping' => { 'email' => 'email', 'firstname' => 'firstname', 'lastname' => 'lastname', 'phone' => 'phone' }
    )
    expect(Time.zone.parse(hook.settings['expires_on'])).to be_within(1.minute).of(30.minutes.from_now)
  end

  it 'updates an existing hook on reconnect and keeps its mapping and toggles' do
    hook = create(:integrations_hook, :hubspot, account: account, status: :disabled)
    hook.update!(settings: hook.settings.merge('sync_contacts' => false, 'reauthorization_required' => true,
                                               'field_mapping' => { 'email' => 'email' }))

    expect { get '/hubspot/callback', params: { code: 'auth-code', state: state } }.not_to change(Integrations::Hook, :count)

    hook.reload
    expect(hook).to be_enabled
    expect(hook.access_token).to eq('new-access-token')
    expect(hook.settings).to include('sync_contacts' => false, 'field_mapping' => { 'email' => 'email' })
    expect(hook.settings).not_to have_key('reauthorization_required')
  end

  it 'redirects with an error flag when the code exchange fails' do
    stub_request(:post, 'https://api.hubapi.com/oauth/2026-03/token').to_return(status: 400, body: '{}')

    get '/hubspot/callback', params: { code: 'auth-code', state: state }

    expect(response).to redirect_to("#{integration_url}?error=1")
    expect(account.hooks.where(app_id: 'hubspot')).to be_empty
  end

  it 'redirects with an error flag when the user denies access' do
    get '/hubspot/callback', params: { error: 'access_denied', state: state }

    expect(response).to redirect_to("#{integration_url}?error=1")
  end

  it 'redirects to the app without touching hooks when the state is invalid' do
    get '/hubspot/callback', params: { code: 'auth-code', state: 'tampered' }

    expect(response).to redirect_to(frontend_url)
    expect(Integrations::Hook.where(app_id: 'hubspot')).to be_empty
  end
end
