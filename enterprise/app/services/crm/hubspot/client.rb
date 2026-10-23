class Crm::Hubspot::Client
  BASE_URL = 'https://api.hubapi.com'.freeze

  class ApiError < StandardError; end
  class NotFoundError < ApiError; end
  class AuthorizationError < ApiError; end
  class ReauthorizationRequired < StandardError; end

  def initialize(hook)
    @token_service = Crm::Hubspot::AccessTokenService.new(hook)
  end

  def properties
    request(:get, '/crm/v3/properties/contacts').fetch('results')
  end

  def upsert_contact(email, properties)
    response = request(:post, '/crm/v3/objects/contacts/batch/upsert',
                       inputs: [{ id: email, idProperty: 'email', properties: properties }])
    result = response.fetch('results', []).first
    raise ApiError, 'HubSpot did not confirm the contact upsert' if response['errors'].present? || result&.[]('id').blank?

    result.fetch('id')
  end

  private

  def request(method, path, body = nil)
    token = @token_service.access_token
    response = perform(method, path, body, token)
    response = perform(method, path, body, @token_service.access_token(rejected_token: token)) if response.code == 401
    # Do not log response bodies: they may contain contact data.
    raise NotFoundError, "HubSpot record not found (HTTP #{response.code})" if response.code == 404
    raise AuthorizationError, "HubSpot rejected the token or scope (HTTP #{response.code})" if [401, 403].include?(response.code)
    raise ApiError, "HubSpot request failed (HTTP #{response.code})" unless response.success?

    response.parsed_response
  end

  def perform(method, path, body, token)
    options = { headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }, timeout: 15 }
    options[:body] = body.to_json if body
    HTTParty.public_send(method, "#{BASE_URL}#{path}", **options)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET
    raise ApiError, 'HubSpot connection failed'
  end
end
