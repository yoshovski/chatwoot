class AiAgents::KnowledgeClient
  # The request never reached the service, so retrying is safe for every action.
  # Covers the knowledge API being briefly unreachable during a deploy.
  CONNECT_ERRORS = [Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout].freeze
  RETRY_DELAYS = [0.25, 0.5].freeze

  def initialize(account:, actor:)
    @account = account
    @actor = actor
  end

  def request(method:, path:, action:, payload: nil)
    attempt = 0
    begin
      perform(method, path, action, payload)
    rescue *CONNECT_ERRORS
      raise if attempt >= RETRY_DELAYS.size

      sleep RETRY_DELAYS[attempt]
      attempt += 1
      retry
    end
  end

  private

  def perform(method, path, action, payload)
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
      body: payload&.to_json, timeout: 30, open_timeout: 3, follow_redirects: false
    )
  end
end
