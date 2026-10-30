# Provisions what a Telnyx voice inbox needs, reusing anything already set in provider_config:
# a TeXML application pointing at our voice webhooks (with the number assigned to it) and a
# credential connection that holds the agents' WebRTC credentials.
class Telnyx::VoiceSetupService
  pattr_initialize [:channel!]

  def perform
    texml_application_id = config['texml_application_id'].presence || create_texml_application
    credential_connection_id = config['credential_connection_id'].presence || create_credential_connection
    assign_number(texml_application_id)

    { 'texml_application_id' => texml_application_id, 'credential_connection_id' => credential_connection_id }
  end

  private

  def config
    channel.provider_config
  end

  def create_texml_application
    body = {
      friendly_name: "Chatwoot #{channel.phone_number}",
      voice_url: channel.voice_call_webhook_url,
      voice_method: 'post',
      status_callback: channel.voice_status_webhook_url,
      status_callback_method: 'post'
    }
    body[:outbound] = { outbound_voice_profile_id: config['outbound_voice_profile_id'] } if config['outbound_voice_profile_id'].present?
    api.post('/texml_applications', body).dig('data', 'id')
  end

  # Agents only ever log in with JWTs minted per credential; the connection's own
  # username/password is never used, so it gets random values.
  def create_credential_connection
    api.post(
      '/credential_connections',
      connection_name: "Chatwoot agents #{channel.phone_number}",
      user_name: "cw#{SecureRandom.alphanumeric(24)}",
      password: SecureRandom.alphanumeric(32)
    ).dig('data', 'id')
  end

  def assign_number(texml_application_id)
    number_id = Telnyx::PhoneNumberLookup.new(client: api).id_for(channel.phone_number)
    raise 'Phone number not found in Telnyx account' if number_id.blank?

    api.patch("/phone_numbers/#{number_id}", connection_id: texml_application_id)
  end

  def api
    @api ||= Telnyx::ApiClient.new(config['api_key'])
  end
end
