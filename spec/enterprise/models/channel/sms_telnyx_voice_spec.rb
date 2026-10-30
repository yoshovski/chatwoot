# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Sms do
  let(:account) { create(:account) }

  describe 'Telnyx voice provisioning' do
    let(:config) { { 'api_key' => 'KEYtest', 'account_sid' => 'acct-uuid', 'voice_enabled' => true } }

    before do
      stub_request(:post, 'https://api.telnyx.com/v2/texml_applications')
        .to_return(status: 201, body: { data: { id: 'texml-new' } }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, 'https://api.telnyx.com/v2/credential_connections')
        .to_return(status: 201, body: { data: { id: 'cc-new' } }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, %r{https://api.telnyx.com/v2/phone_numbers})
        .to_return(status: 200, body: { data: [{ id: 'pn-1' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:patch, 'https://api.telnyx.com/v2/phone_numbers/pn-1')
        .with(body: { connection_id: 'texml-new' }.to_json)
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates the TeXML application and credential connection and assigns the number' do
      channel = create(:channel_sms, account: account, provider: 'telnyx', phone_number: '+15551230011', provider_config: config)

      expect(channel.provider_config).to include('texml_application_id' => 'texml-new', 'credential_connection_id' => 'cc-new')
      expect(channel.voice_configured?).to be true
      expect(channel.voice_provider).to eq(:telnyx)
    end

    it 'fails validation without the Telnyx account id' do
      channel = build(:channel_sms, account: account, provider: 'telnyx', provider_config: config.except('account_sid'))

      expect(channel).not_to be_valid
      expect(channel.errors[:base].first).to include('account ID is required')
    end

    it 'keeps provisioned ids when a settings update replaces provider_config' do
      channel = create(:channel_sms, account: account, provider: 'telnyx', phone_number: '+15551230012', provider_config: config)

      channel.update!(provider_config: config.merge('public_key' => 'abc'))

      expect(channel.reload.provider_config).to include('texml_application_id' => 'texml-new', 'public_key' => 'abc')
    end
  end

  it 'reports no voice for Bandwidth inboxes' do
    channel = create(:channel_sms, account: account)

    expect(channel.voice_enabled?).to be false
    expect(channel.voice_provider).to be_nil
  end
end
