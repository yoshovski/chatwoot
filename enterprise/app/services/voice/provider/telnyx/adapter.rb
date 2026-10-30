class Voice::Provider::Telnyx::Adapter
  STATUS_EVENTS = 'initiated ringing answered completed'.freeze

  def initialize(channel)
    @channel = channel
  end

  # The provider_call_id is our own reference: Telnyx's create-call response carries no CallSid,
  # and every webhook for this leg comes back with `call_ref` in its URL instead.
  def initiate_call(to:, conference_sid: nil, agent_id: nil)
    call_ref = "telnyx-#{SecureRandom.uuid}"
    texml_client.create_call(
      to: to,
      url: @channel.voice_call_webhook_url(call_ref: call_ref),
      status_callback: @channel.voice_status_webhook_url(call_ref: call_ref),
      status_callback_events: STATUS_EVENTS
    )

    {
      provider: 'telnyx',
      call_sid: call_ref,
      status: 'queued',
      call_direction: 'outbound',
      requires_agent_join: true,
      agent_id: agent_id,
      conference_sid: conference_sid
    }
  end

  private

  def texml_client
    @texml_client ||= Voice::Provider::Telnyx::TexmlClient.new(@channel)
  end
end
