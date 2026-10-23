class Crm::Hubspot::Client
  class ApiError < StandardError; end

  def initialize(token)
    @headers = { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
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
    options = { headers: @headers, timeout: 15 }
    options[:body] = body.to_json if body
    response = HTTParty.public_send(method, "https://api.hubapi.com#{path}", **options)
    # Do not log response bodies: validation errors may contain lead data.
    raise ApiError, "HubSpot request failed (HTTP #{response.code})" unless response.success?

    response.parsed_response
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET
    raise ApiError, 'HubSpot connection failed'
  end
end
