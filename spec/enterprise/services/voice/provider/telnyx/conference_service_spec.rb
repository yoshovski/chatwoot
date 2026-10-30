# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Voice::Provider::Telnyx::ConferenceService do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_sms, :telnyx_voice, account: account, phone_number: '+15551230010') }
  let(:agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox) }
  let(:call) do
    create(:call, account: account, inbox: channel.inbox, conversation: conversation, contact: conversation.contact,
                  provider: :telnyx, provider_call_id: 'v3:inbound-1')
  end
  let(:service) { described_class.new(call: call) }
  let(:calls_url) { 'https://api.telnyx.com/v2/texml/Accounts/acct-uuid/Calls' }

  describe '#mark_agent_joined' do
    it 'claims the call and rings the agent credential with the agent leg TeXML' do
      stub_request(:post, 'https://api.telnyx.com/v2/telephony_credentials')
        .to_return(status: 201, body: { data: { id: 'cred-1', sip_username: 'gencred123' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      dial = stub_request(:post, calls_url)
             .with(body: hash_including('To' => 'sip:gencred123@sip.telnyx.com', 'From' => '+15551230010', 'ApplicationSid' => 'texml-1'))
             .to_return(status: 200, body: { status: 'queued' }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.mark_agent_joined(user: agent)

      expect(call.reload.accepted_by_agent_id).to eq(agent.id)
      expect(dial).to have_been_requested
      expect(channel.reload.provider_config.dig('agent_credentials', agent.id.to_s)).to eq('id' => 'cred-1', 'sip_username' => 'gencred123')
    end

    it 'reuses the stored credential' do
      channel.update!(provider_config: channel.provider_config.merge('agent_credentials' => { agent.id.to_s => { 'id' => 'cred-9',
                                                                                                                 'sip_username' => 'known' } }))
      dial = stub_request(:post, calls_url).with(body: hash_including('To' => 'sip:known@sip.telnyx.com'))
                                           .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      service.mark_agent_joined(user: agent)

      expect(dial).to have_been_requested
      expect(a_request(:post, 'https://api.telnyx.com/v2/telephony_credentials')).not_to have_been_made
    end
  end

  describe '#end_conference' do
    it 'hangs up the contact leg and every agent leg' do
      call.update!(telnyx_call_sid: 'v3:inbound-1', agent_leg_labels: { 'v3:agent-1' => 'agent-1-account-1' })
      contact_hangup = stub_request(:post, "#{calls_url}/v3:inbound-1").with(body: 'Status=completed').to_return(status: 200, body: '{}')
      agent_hangup = stub_request(:post, "#{calls_url}/v3:agent-1").to_return(status: 404, body: '{}')

      service.end_conference

      expect(contact_hangup).to have_been_requested
      expect(agent_hangup).to have_been_requested
    end
  end
end
