# Thin wrapper around the Telnyx v2 REST API. Every response is JSON wrapped in `data`;
# failures carry an `errors` array that we flatten into the raised message.
class Telnyx::ApiClient
  BASE_URL = 'https://api.telnyx.com/v2'.freeze

  class Error < StandardError
    attr_reader :status, :code

    def initialize(message, status: nil, code: nil)
      super(message)
      @status = status
      @code = code
    end
  end

  def initialize(api_key)
    raise ArgumentError, 'Telnyx API key is required' if api_key.blank?

    @api_key = api_key
  end

  def get(path, query: {})
    request(:get, path, query: query)
  end

  def post(path, body = {})
    request(:post, path, body: body.to_json)
  end

  def patch(path, body = {})
    request(:patch, path, body: body.to_json)
  end

  # TeXML call updates mirror Twilio's REST API and only take form-encoded bodies.
  def post_form(path, form = {})
    request(:post, path, body: URI.encode_www_form(form), content_type: 'application/x-www-form-urlencoded')
  end

  private

  def request(method, path, body: nil, query: nil, content_type: 'application/json')
    response = HTTParty.send(
      method,
      "#{BASE_URL}#{path}",
      headers: { 'Authorization' => "Bearer #{@api_key}", 'Content-Type' => content_type, 'Accept' => 'application/json' },
      body: body,
      query: query.presence,
      timeout: 15
    )
    raise_error(response) unless response.success?

    response.parsed_response
  end

  def raise_error(response)
    parsed = response.parsed_response
    error = parsed.is_a?(Hash) ? Array(parsed['errors']).first : nil
    message = error ? [error['title'], error['detail']].compact.uniq.join(': ') : "HTTP #{response.code}"
    raise Error.new("Telnyx API error: #{message}", status: response.code, code: error&.dig('code'))
  end
end
