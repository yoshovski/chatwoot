# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'json'
require 'active_support/core_ext/object/blank'

module ShopifyAgentTools; end unless defined?(ShopifyAgentTools)

class ShopifyAgentTools::Client
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end

  def initialize(tool_key:, api_url: ENV.fetch('SAT_API_URL', nil))
    @api_url = (api_url.presence || 'https://shopify-tools.chatoctave.com').chomp('/')
    @tool_key = tool_key.to_s.strip

    raise Error, 'Shopify Agent Tools tool key is missing' if @tool_key.blank?

    @connection = Faraday.new(url: @api_url, headers: { 'Authorization' => "Bearer #{@tool_key}" }) do |connection|
      connection.request :retry, max: 2, interval: 0.5, backoff_factor: 2, methods: %i[get post], retry_statuses: [429, 502, 503, 504]
      connection.options.open_timeout = 5
      connection.options.timeout = 30
      connection.adapter Faraday.default_adapter
    end
  end

  def search_products(query:, limit: 5)
    request(:post, 'v1/tools/shopify/search-products', { query: query, limit: limit })
  end

  def get_product(handle:)
    request(:post, 'v1/tools/shopify/get-product', { handle: handle })
  rescue Error => e
    return nil if e.status == 404

    raise
  end

  def get_inventory(handle:)
    request(:post, 'v1/tools/shopify/get-inventory', { handle: handle })
  rescue Error => e
    return nil if e.status == 404

    raise
  end

  def browse_catalog(query: nil, limit: 10)
    payload = { limit: limit }
    payload[:query] = query if query.present?
    request(:post, 'v1/tools/shopify/browse-catalog', payload)
  end

  def track_order(order_number:, customer_email:)
    payload = { order_number: order_number, customer_email: customer_email }
    request(:post, 'v1/tools/shopify/track-order', payload)
  end

  private

  def request(method, path, payload = nil, params: {})
    response = @connection.run_request(method, path, nil, nil) do |req|
      req.headers['Content-Type'] = 'application/json' if payload
      req.body = payload.to_json if payload
      req.params.update(params) if params.present?
    end

    raise Error.new("SAT tool request failed (HTTP #{response.status})", status: response.status) unless response.success?

    JSON.parse(response.body) unless response.body.to_s.empty?
  rescue Faraday::Error, JSON::ParserError => e
    raise Error, "SAT tool request failed: #{e.message}"
  end
end
