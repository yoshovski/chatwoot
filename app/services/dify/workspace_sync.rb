class Dify::WorkspaceSync
  class Error < StandardError; end

  def self.call(workspace, actor:)
    ShopifyAgentTools::AdminClient.new.configure_dify_platform(workspace) if workspace.enabled? && workspace.shopify_configured?
    now = Time.current.to_i
    token = JWT.encode(
      { iss: ENV.fetch('CWAI_INSTALLATION_ID'), aud: 'cwai-knowledge', sub: actor.id.to_s,
        account_id: 0, action: 'knowledge:configure', iat: now, nbf: now, exp: now + 60 },
      ENV.fetch('CWAI_SIGNING_KEY'), 'HS256'
    )
    response = HTTParty.put(
      "#{ENV.fetch('CWAI_SERVICE_URL').chomp('/')}/v1/knowledge/workspace",
      headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' },
      body: { enabled: workspace.enabled?, connection: workspace.enabled? ? workspace.connection : nil }.to_json,
      timeout: 30, follow_redirects: false
    )
    raise Error, 'Knowledge workspace configuration could not be applied' unless response.code == 204
  rescue HTTParty::Error, Timeout::Error, SocketError, SystemCallError, ShopifyAgentTools::AdminClient::Error
    raise Error, 'Knowledge workspace service is unavailable'
  end
end
