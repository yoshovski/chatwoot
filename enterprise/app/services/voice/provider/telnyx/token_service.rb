class Voice::Provider::Telnyx::TokenService
  pattr_initialize [:inbox!, :user!, :account!]

  def generate
    {
      provider: 'telnyx',
      token: credential_service.login_token,
      identity: "agent-#{user.id}-account-#{account.id}",
      voice_enabled: true,
      agent_id: user.id,
      account_id: account.id,
      inbox_id: inbox.id,
      phone_number: inbox.channel.phone_number
    }
  end

  private

  def credential_service
    @credential_service ||= Voice::Provider::Telnyx::AgentCredentialService.new(channel: inbox.channel, user: user)
  end
end
