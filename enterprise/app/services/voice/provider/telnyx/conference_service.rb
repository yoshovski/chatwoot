# Telnyx agents don't dial into the conference from the browser like Twilio's Device does.
# Once the agent claims the call we ring their WebRTC credential over SIP, and the TeXML
# served for that leg drops them into the conference.
class Voice::Provider::Telnyx::ConferenceService < Voice::Provider::BaseConferenceService
  def mark_agent_joined(user:)
    super
    dial_agent!(user)
  end

  def end_conference
    leg_sids = [call.telnyx_call_sid, *(call.agent_leg_labels || {}).keys].compact_blank.uniq
    leg_sids.each { |sid| texml_client.hangup(sid) }
  end

  private

  def dial_agent!(user)
    credential = Voice::Provider::Telnyx::AgentCredentialService.new(channel: channel, user: user).credential
    texml_client.create_call(
      to: Voice::Provider::Telnyx::TexmlClient.sip_uri(credential['sip_username']),
      url: channel.voice_call_webhook_url(agent_call_id: call.id, agent_id: user.id)
    )
  end

  def channel
    @channel ||= call.inbox.channel
  end

  def texml_client
    @texml_client ||= Voice::Provider::Telnyx::TexmlClient.new(channel)
  end
end
