# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Telnyx::VoiceController', type: :request do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_sms, :telnyx_voice, account: account, phone_number: '+15551230009') }
  let(:inbox) { channel.inbox }
  let(:digits) { '15551230009' }
  let(:contact_number) { '+15550007777' }

  def create_call(**attrs)
    conversation = create(:conversation, account: account, inbox: inbox)
    create(:call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                  provider: :telnyx, **attrs)
  end

  describe 'POST /telnyx/voice/call/:phone' do
    it 'creates the inbound call and puts the caller in its conference' do
      post "/telnyx/voice/call/#{digits}", params: { CallSid: 'v3:inbound-1', From: contact_number, To: channel.phone_number,
                                                     Direction: 'inbound' }

      call = Call.find_by!(provider: :telnyx, provider_call_id: 'v3:inbound-1')
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<Conference', call.conference_sid, 'participantLabel="contact"',
                                       'startConferenceOnEnter="false"', "call_id=#{call.id}")
      expect(call.telnyx_call_sid).to eq('v3:inbound-1')
      expect(call.contact.phone_number).to eq(contact_number)
    end

    it 'hangs up inbound calls when inbound calling is turned off' do
      channel.update!(provider_config: channel.provider_config.merge('inbound_calls_enabled' => false))

      expect do
        post "/telnyx/voice/call/#{digits}", params: { CallSid: 'v3:inbound-2', From: contact_number, Direction: 'inbound' }
      end.not_to change(Call, :count)
      expect(response.body).to include('<Hangup/>')
    end

    it 'joins the answered outbound leg to the call it was placed for' do
      call = create_call(provider_call_id: 'telnyx-ref-1', direction: :outgoing)

      post "/telnyx/voice/call/#{digits}", params: { call_ref: 'telnyx-ref-1', CallSid: 'v3:out-1', Direction: 'outbound-api' }

      expect(response.body).to include(call.reload.conference_sid.to_s)
      expect(call.telnyx_call_sid).to eq('v3:out-1')
    end

    it 'bridges the agent who claimed the call and remembers the leg' do
      agent = create(:user, account: account)
      call = create_call(provider_call_id: 'v3:inbound-3', accepted_by_agent: agent)

      post "/telnyx/voice/call/#{digits}", params: { agent_call_id: call.id, agent_id: agent.id, CallSid: 'v3:agent-1' }

      label = "agent-#{agent.id}-account-#{account.id}"
      expect(response.body).to include("participantLabel=\"#{label}\"", 'startConferenceOnEnter="true"')
      expect(call.reload.agent_leg_labels).to eq('v3:agent-1' => label)
    end

    it 'hangs up an agent leg for an agent who did not claim the call' do
      call = create_call(provider_call_id: 'v3:inbound-4')

      post "/telnyx/voice/call/#{digits}", params: { agent_call_id: call.id, agent_id: 999, CallSid: 'v3:agent-2' }

      expect(response.body).to include('<Hangup/>')
    end

    it 'rejects unsigned requests once a public key is configured' do
      channel.update!(provider_config: channel.provider_config.merge('public_key' => Base64.strict_encode64('k' * 32)))

      post "/telnyx/voice/call/#{digits}", params: { CallSid: 'v3:inbound-5', From: contact_number, Direction: 'inbound' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /telnyx/voice/status/:phone' do
    it 'maps the TeXML status onto the call found by its reference' do
      call = create_call(provider_call_id: 'telnyx-ref-2', direction: :outgoing)

      post "/telnyx/voice/status/#{digits}", params: { call_ref: 'telnyx-ref-2', CallSid: 'v3:out-2', CallStatus: 'no-answer' }

      expect(response).to have_http_status(:no_content)
      expect(call.reload.status).to eq('no_answer')
      expect(call.telnyx_call_sid).to eq('v3:out-2')
    end
  end

  describe 'POST /telnyx/voice/conference_status/:phone' do
    it 'claims the call when the agent leg joins, using the remembered label' do
      agent = create(:user, account: account)
      call = create_call(provider_call_id: 'v3:inbound-6')
      call.update!(agent_leg_labels: { 'v3:agent-3' => "agent-#{agent.id}-account-#{account.id}" })

      post "/telnyx/voice/conference_status/#{digits}",
           params: { call_id: call.id, StatusCallbackEvent: 'participant-join', CallSid: 'v3:agent-3' }

      expect(call.reload.status).to eq('in_progress')
      expect(call.accepted_by_agent_id).to eq(agent.id)
    end
  end

  describe 'POST /telnyx/voice/recording_status/:phone' do
    it 'queues the recording download' do
      call = create_call(provider_call_id: 'v3:inbound-7')

      expect do
        post "/telnyx/voice/recording_status/#{digits}",
             params: { call_id: call.id, RecordingStatus: 'completed', RecordingSid: 'rec-1', RecordingUrl: 'https://s3.example.com/rec.wav' }
      end.to have_enqueued_job(Voice::Provider::Telnyx::RecordingAttachmentJob).with(call.id, 'rec-1', 'https://s3.example.com/rec.wav', nil)
    end
  end
end
