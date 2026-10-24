# HubSpot is retiring the v1 OAuth endpoints (sunset 2027-02-16); these are the date-versioned replacements.
class Crm::Hubspot::OauthClient
  AUTHORIZE_URL = 'https://app.hubspot.com/oauth/authorize'.freeze
  API_URL = 'https://api.hubapi.com/oauth/2026-03'.freeze
  SCOPES = %w[oauth crm.objects.contacts.read crm.objects.contacts.write crm.schemas.contacts.read].freeze
  OPTIONAL_SCOPES = %w[crm.objects.owners.read].freeze

  class Error < StandardError; end
  class InvalidGrantError < Error; end

  def self.redirect_uri
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/hubspot/callback"
  end

  def authorize_url(state)
    query = { client_id: client_id, redirect_uri: self.class.redirect_uri, scope: SCOPES.join(' '),
              optional_scope: OPTIONAL_SCOPES.join(' '), state: state }
    "#{AUTHORIZE_URL}?#{query.to_query}"
  end

  def exchange_code(code)
    post('/token', grant_type: 'authorization_code', redirect_uri: self.class.redirect_uri, code: code)
  end

  def refresh(refresh_token)
    post('/token', grant_type: 'refresh_token', refresh_token: refresh_token)
  end

  def introspect(access_token)
    post('/token/introspect', token: access_token, token_type_hint: 'access_token')
  end

  def revoke(refresh_token)
    post('/token/revoke', token: refresh_token, token_type_hint: 'refresh_token')
  end

  private

  def post(path, body)
    response = HTTParty.post("#{API_URL}#{path}", body: body.merge(client_id: client_id, client_secret: client_secret),
                                                  headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }, timeout: 15)
    # Do not log response bodies: they carry tokens.
    raise InvalidGrantError, "HubSpot rejected the grant (HTTP #{response.code})" if [400, 401].include?(response.code)
    raise Error, "HubSpot OAuth request failed (HTTP #{response.code})" unless response.success?

    response.parsed_response
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET
    raise Error, 'HubSpot connection failed'
  end

  def client_id = GlobalConfigService.load('HUBSPOT_CLIENT_ID', nil)
  def client_secret = GlobalConfigService.load('HUBSPOT_CLIENT_SECRET', nil)
end
