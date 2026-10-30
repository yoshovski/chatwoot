# TeXML webhooks for Telnyx voice inboxes. Telnyx sends Twilio-compatible form params
# (CallSid, From, To, Direction, CallStatus, ...). Legs we start ourselves carry our own
# reference in the query string, because Telnyx's create-call response has no CallSid:
#   call_ref       outbound contact leg (Call#provider_call_id)
#   agent_call_id  agent leg dialed to the agent's WebRTC credential
#   call_id        conference and recording callbacks for a known call
class Telnyx::VoiceController < ApplicationController
  CONFERENCE_EVENT_PATTERNS = {
    /conference-start/i => 'start',
    /participant-join/i => 'join',
    /participant-leave/i => 'leave',
    /conference-end/i => 'end'
  }.freeze

  skip_forgery_protection
  before_action :set_inbox!
  before_action :verify_signature!

  def call_texml
    Rails.logger.info(
      "TELNYX_VOICE_TEXML account=#{inbox.account_id} call_sid=#{params[:CallSid]} direction=#{params[:Direction]} " \
      "call_ref=#{params[:call_ref]} agent_call_id=#{params[:agent_call_id]}"
    )

    render xml: texml_for_leg
  end

  def status
    call = call_for_status
    persist_telnyx_call_sid!(call) if call

    Voice::StatusUpdateService.new(
      account: inbox.account,
      call_sid: call&.provider_call_id || params[:CallSid].to_s,
      call_status: params[:CallStatus],
      payload: params.to_unsafe_h,
      provider: :telnyx
    ).perform

    head :no_content
  end

  def conference_status
    event = mapped_conference_event
    return head :no_content if event.nil?

    call = inbox_calls.find(params[:call_id])
    Voice::Conference::Manager.new(call: call, event: event, participant_label: participant_label(call)).process

    head :no_content
  end

  def recording_status
    call = inbox_calls.find(params[:call_id])
    if recording_completed? && params[:RecordingUrl].present?
      Voice::Provider::Telnyx::RecordingAttachmentJob.perform_later(
        call.id, params[:RecordingSid].presence || params[:CallSid], params[:RecordingUrl], params[:RecordingDuration]
      )
    end

    head :no_content
  end

  private

  attr_reader :inbox

  def texml_for_leg
    return agent_leg_texml if params[:agent_call_id].present?
    return conference_texml(outbound_contact_call, participant_label: 'contact', agent: false) if params[:call_ref].present?
    return Voice::Provider::Telnyx::Texml.hangup unless inbound_contact_leg? && inbox.channel.inbound_calls_enabled?

    conference_texml(inbound_contact_call, participant_label: 'contact', agent: false)
  end

  def inbound_contact_leg?
    params[:Direction].to_s == 'inbound'
  end

  def inbound_contact_call
    call = Voice::InboundCallBuilder.perform!(
      inbox: inbox,
      call_sid: params[:CallSid],
      provider: :telnyx,
      caller: { source_ids: [params[:From]], contact_attributes: { name: params[:From], phone_number: params[:From] } },
      extra_meta: { telnyx_call_sid: params[:CallSid] }
    )
    persist_telnyx_call_sid!(call)
    call
  end

  def outbound_contact_call
    call = inbox_calls.find_by!(provider_call_id: params[:call_ref])
    persist_telnyx_call_sid!(call)
    call
  end

  # Only the agent who claimed the call may be bridged in; anything else is hung up.
  def agent_leg_texml
    call = inbox_calls.find(params[:agent_call_id])
    agent_id = params[:agent_id].to_i
    return Voice::Provider::Telnyx::Texml.hangup if call.terminal? || call.accepted_by_agent_id != agent_id

    label = "agent-#{agent_id}-account-#{call.account_id}"
    remember_agent_leg!(call, params[:CallSid], label)
    conference_texml(call, participant_label: label, agent: true)
  end

  def conference_texml(call, participant_label:, agent:)
    conference_sid = Voice::Provider::Telnyx::ConferenceService.new(call: call).ensure_conference_sid
    Voice::Provider::Telnyx::Texml.conference(
      conference_sid,
      participant_label: participant_label,
      agent: agent,
      record: call.recording_enabled?,
      callbacks: {
        status: inbox.channel.voice_conference_status_webhook_url(call_id: call.id),
        recording: inbox.channel.voice_recording_status_webhook_url(call_id: call.id)
      }
    )
  end

  def call_for_status
    return inbox_calls.find_by(provider_call_id: params[:call_ref]) if params[:call_ref].present?

    inbox_calls.find_by(provider_call_id: params[:CallSid]) if params[:CallSid].present?
  end

  # The contact leg's Telnyx CallSid is what we hang up when an agent ends or rejects the call.
  def persist_telnyx_call_sid!(call)
    sid = params[:CallSid].presence
    return if sid.blank? || call.telnyx_call_sid == sid

    call.update!(telnyx_call_sid: sid)
  end

  def remember_agent_leg!(call, sid, label)
    return if sid.blank?

    call.with_lock do
      call.update!(agent_leg_labels: (call.agent_leg_labels || {}).merge(sid => label))
    end
  end

  # Telnyx only includes ParticipantLabel when it has one, so fall back to the label
  # recorded when we served the agent leg its TeXML.
  def participant_label(call)
    params[:ParticipantLabel].presence || (call.agent_leg_labels || {})[params[:CallSid].to_s].to_s
  end

  def mapped_conference_event
    event = params[:StatusCallbackEvent].to_s
    CONFERENCE_EVENT_PATTERNS.each { |pattern, mapped| return mapped if event.match?(pattern) }
    nil
  end

  def recording_completed?
    status = params[:RecordingStatus].to_s
    status.blank? || status.casecmp('completed').zero?
  end

  def inbox_calls
    Call.where(inbox_id: inbox.id, provider: :telnyx)
  end

  def set_inbox!
    digits = params[:phone].to_s.gsub(/\D/, '')
    channel = Channel::Sms.find_by!(phone_number: "+#{digits}", provider: 'telnyx')
    raise ActiveRecord::RecordNotFound, "Voice not enabled for +#{digits}" unless channel.voice_enabled?

    @inbox = channel.inbox
  end

  def verify_signature!
    head :unauthorized unless Telnyx::WebhookSignature.verify_request!(inbox.channel, request)
  end
end
