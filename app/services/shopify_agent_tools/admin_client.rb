module ShopifyAgentTools; end unless defined?(ShopifyAgentTools)

class ShopifyAgentTools::AdminClient
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end

  def initialize(api_url: ENV.fetch('SAT_API_URL', nil), admin_key: ENV.fetch('SAT_ADMIN_KEY', nil))
    @api_url = (api_url.presence || 'https://shopify-tools.chatoctave.com').chomp('/')
    @admin_key = admin_key.presence || ENV.fetch('SAT_ADMIN_KEY', nil)

    raise Error, 'Shopify Agent Tools admin key is missing' if @admin_key.blank?

    @connection = Faraday.new(url: @api_url, headers: { 'Authorization' => "Bearer #{@admin_key}" }) do |connection|
      connection.request :retry, max: 2, interval: 0.5, backoff_factor: 2, methods: %i[get delete], retry_statuses: [429, 502, 503, 504]
      connection.options.open_timeout = 5
      connection.options.timeout = 30
      connection.adapter Faraday.default_adapter
    end
  end

  def create_tenant(name:, slug:, shop_domain:)
    request(:post, 'v1/admin/tenants', { name: name, slug: slug, shop_domain: shop_domain })
  end

  def configure_shopify(tenant_id, client_id:, client_secret:, storefront_base_url: nil)
    payload = {
      client_id: client_id,
      client_secret: client_secret,
      storefront_base_url: storefront_base_url
    }.compact
    request(:put, "v1/admin/tenants/#{tenant_id}/shopify", payload)
  end

  def tenant(tenant_id)
    request(:get, "v1/admin/tenants/#{tenant_id}")
  end

  def rotate_tool_key(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/tool-key/rotate")
  end

  def delete_tenant(tenant_id)
    request(:delete, "v1/admin/tenants/#{tenant_id}")
  end

  def provision_dify_dataset(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/dify/provision")
  end

  def dify_dataset(tenant_id)
    request(:get, "v1/admin/tenants/#{tenant_id}/dify")
  end

  def start_catalog_import(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/catalog/import")
  end

  def catalog_status(tenant_id)
    request(:get, "v1/admin/tenants/#{tenant_id}/catalog/status")
  end

  def pause_catalog_sync(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/catalog/pause")
  end

  def resume_catalog_sync(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/catalog/resume")
  end

  private

  def request(method, path, payload = nil, params: {})
    response = @connection.run_request(method, path, nil, nil) do |req|
      req.headers['Content-Type'] = 'application/json' if payload
      req.body = payload.to_json if payload
      req.params.update(params) if params.present?
    end

    raise Error.new("SAT request failed (HTTP #{response.status})", status: response.status) unless response.success?

    JSON.parse(response.body) unless response.body.to_s.empty?
  rescue Faraday::Error, JSON::ParserError => e
    raise Error, "SAT request failed: #{e.message}"
  end
end
