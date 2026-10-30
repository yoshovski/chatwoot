# One Telnyx telephony credential per agent per inbox, created on first use on the inbox's
# credential connection. The browser logs in with a JWT minted for it, and we reach the
# agent by dialing its SIP username.
class Voice::Provider::Telnyx::AgentCredentialService
  pattr_initialize [:channel!, :user!]

  def credential
    existing = stored_credential
    return existing if existing.present?

    channel.with_lock do
      stored_credential.presence || create_credential!
    end
  end

  # Telnyx returns the JWT as the raw response body.
  def login_token
    response = api.post("/telephony_credentials/#{credential['id']}/token")
    response.is_a?(Hash) ? response.dig('data', 'token') || response['token'] : response.to_s
  end

  private

  def stored_credential
    channel.provider_config.dig('agent_credentials', user.id.to_s)
  end

  def create_credential!
    data = api.post(
      '/telephony_credentials',
      connection_id: channel.provider_config['credential_connection_id'],
      name: "chatwoot-agent-#{user.id}-account-#{channel.account_id}"
    )['data']
    store_credential!('id' => data['id'], 'sip_username' => data['sip_username'])
  end

  def store_credential!(credential)
    credentials = (channel.provider_config['agent_credentials'] || {}).merge(user.id.to_s => credential)
    channel.provider_config = channel.provider_config.merge('agent_credentials' => credentials)
    channel.save!(validate: false)
    credential
  end

  def api
    @api ||= ::Telnyx::ApiClient.new(channel.provider_config['api_key'])
  end
end
