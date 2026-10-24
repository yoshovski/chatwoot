require 'rails_helper'

RSpec.describe Crm::Hubspot::AccessTokenService do
  let(:hook) { create(:integrations_hook, :hubspot) }
  let(:service) { described_class.new(hook) }
  let(:token_url) { 'https://api.hubapi.com/oauth/2026-03/token' }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return('test-client-id')
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_SECRET', nil).and_return('test-client-secret')
  end

  it 'returns the stored token while it is valid' do
    expect(service.access_token).to eq('hubspot-access-token')
  end

  context 'when the token expires within a minute' do
    before { hook.update!(settings: hook.settings.merge('expires_on' => 30.seconds.from_now.utc.iso8601)) }

    it 'refreshes and stores the new tokens' do
      stub_request(:post, token_url)
        .with(body: hash_including('grant_type' => 'refresh_token', 'refresh_token' => 'na1-refresh-token'))
        .to_return(status: 200, body: { access_token: 'fresh-token', refresh_token: 'na1-rotated', expires_in: 1800 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.access_token).to eq('fresh-token')
      expect(hook.reload.access_token).to eq('fresh-token')
      expect(hook.settings['refresh_token']).to eq('na1-rotated')
      expect(Time.zone.parse(hook.settings['expires_on'])).to be_within(1.minute).of(30.minutes.from_now)
    end

    it 'disables the hook and flags reauthorization when HubSpot rejects the refresh token' do
      stub_request(:post, token_url).to_return(status: 400, body: { error: 'invalid_grant' }.to_json)

      expect { service.access_token }.to raise_error(Crm::Hubspot::Client::ReauthorizationRequired)
      expect(hook.reload).to be_disabled
      expect(hook.settings['reauthorization_required']).to be(true)
    end

    it 'raises a retryable error when another worker holds the refresh lock' do
      Redis::LockManager.new.lock(format(Redis::Alfred::HUBSPOT_TOKEN_REFRESH_MUTEX, hook_id: hook.id), 20.seconds)

      expect { service.access_token }.to raise_error(Crm::Hubspot::Client::ApiError)
    ensure
      Redis::LockManager.new.unlock(format(Redis::Alfred::HUBSPOT_TOKEN_REFRESH_MUTEX, hook_id: hook.id))
    end
  end

  it 'refreshes a rejected token even when it has not expired' do
    stub_request(:post, token_url).to_return(status: 200, body: { access_token: 'fresh-token', expires_in: 1800 }.to_json,
                                             headers: { 'Content-Type' => 'application/json' })

    expect(service.access_token(rejected_token: 'hubspot-access-token')).to eq('fresh-token')
    expect(hook.reload.settings['refresh_token']).to eq('na1-refresh-token')
  end

  it 'reuses a token another worker already refreshed' do
    Integrations::Hook.find(hook.id).update!(access_token: 'other-worker-token')

    expect(service.access_token(rejected_token: 'hubspot-access-token')).to eq('other-worker-token')
  end
end
