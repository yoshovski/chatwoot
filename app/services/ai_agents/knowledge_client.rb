class AiAgents::KnowledgeClient
  def initialize(account:, actor:)
    @account = account
    @actor = actor
  end

  def request(method:, path:, action:, payload: nil)
    now = Time.current.to_i
    token = JWT.encode(
      {
        iss: ENV.fetch('CWAI_INSTALLATION_ID'), aud: 'cwai-knowledge', sub: @actor.id.to_s,
        account_id: @account.id, action: action, iat: now, nbf: now, exp: now + 60
      },
      ENV.fetch('CWAI_SIGNING_KEY'), 'HS256'
    )
    HTTParty.public_send(
      method, "#{ENV.fetch('CWAI_SERVICE_URL').chomp('/')}#{path}",
      headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' },
      body: payload&.to_json, timeout: 30, follow_redirects: false
    )
  end
end
