class Voice::Provider::Twilio::ConferenceService < Voice::Provider::BaseConferenceService
  def end_conference
    return if call.conference_sid.blank?

    client = call.inbox.channel.client
    client
      .conferences
      .list(friendly_name: call.conference_sid, status: 'in-progress')
      .each { |conf| client.conferences(conf.sid).update(status: 'completed') }
  end
end
