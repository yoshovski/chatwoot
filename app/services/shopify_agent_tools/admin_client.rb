module ShopifyAgentTools; end unless defined?(ShopifyAgentTools)

class ShopifyAgentTools::AdminClient
  CATALOG_PAGE_SIZE = 50

  class Error < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end

  DEFAULT_API_URL = 'https://shopify-tools.chatoctave.com'.freeze

  # SAT_API_URL from the environment or the installation config, for both the admin and the tool client.
  def self.api_url
    ENV.fetch('SAT_API_URL', nil).presence || global_config('SAT_API_URL').presence || DEFAULT_API_URL
  end

  def self.global_config(key)
    GlobalConfigService.load(key, nil) if defined?(GlobalConfigService)
  end

  def initialize(api_url: nil, admin_key: nil)
    @api_url = (api_url.presence || self.class.api_url).chomp('/')
    @admin_key = admin_key.presence || ENV.fetch('SAT_ADMIN_KEY', nil).presence || self.class.global_config('SAT_ADMIN_KEY')

    raise Error, 'Shopify Agent Tools admin key is missing' if @admin_key.blank?

    @connection = Faraday.new(
      url: @api_url,
      headers: {
        'Authorization' => "Bearer #{@admin_key}",
        'X-Admin-Key' => @admin_key
      }
    ) do |connection|
      connection.request :retry, max: 2, interval: 0.5, backoff_factor: 2, methods: %i[get delete], retry_statuses: [429, 502, 503, 504]
      connection.options.open_timeout = 5
      connection.options.timeout = 30
      connection.adapter Faraday.default_adapter
    end
  end

  def create_tenant(name:, slug:, shop_domain:)
    request(:post, 'v1/admin/tenants', { name: name, slug: slug, shop_domain: shop_domain })
  end

  def configure_shopify(tenant_id, client_id:, client_secret:, shop_domain: nil, storefront_base_url: nil)
    shop_domain ||= tenant(tenant_id)['shop_domain'] if tenant_id.present?
    payload = {
      shop_domain: shop_domain,
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

  def dify_platform_settings
    request(:get, 'v1/admin/settings/dify')
  end

  def configure_dify_platform(workspace)
    profile_fields = %w[parent_mode parent_separator parent_max_tokens child_separator child_max_tokens normalize_whitespace remove_urls_emails]
    payload = dify_platform_settings.slice(*profile_fields).compact.merge(
      workspace.attributes.slice(*DifyWorkspace::CONFIGURATION_FIELDS).merge('api_key' => workspace.knowledge_api_key)
    )
    request(:put, 'v1/admin/settings/dify', payload)
  end

  def start_catalog_import(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/catalog/import")
  end

  def catalog_status(tenant_id)
    request(:get, "v1/admin/tenants/#{tenant_id}/catalog/status")
  end

  def catalog_documents(tenant_id, status: nil, query: nil, page: 1)
    params = { status: status, q: query, page: page, page_size: CATALOG_PAGE_SIZE }.compact_blank
    request(:get, "v1/admin/tenants/#{tenant_id}/catalog/documents", params: params)
  end

  def pause_catalog_sync(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/catalog/pause")
  end

  def resume_catalog_sync(tenant_id)
    request(:post, "v1/admin/tenants/#{tenant_id}/catalog/resume")
  end

  private

  def request(method, path, payload = nil, params: {})
    response = execute_request(method, path, payload, params)
    raise Error.new(build_error_message(response), status: response.status) unless response.success?

    JSON.parse(response.body) unless response.body.to_s.empty?
  rescue Faraday::Error, JSON::ParserError => e
    raise Error, "SAT request failed: #{e.message}"
  end

  def execute_request(method, path, payload, params)
    @connection.run_request(method, path, nil, nil) do |req|
      req.headers['Content-Type'] = 'application/json' if payload
      req.body = payload.to_json if payload
      req.params.update(params) if params.present?
    end
  end

  def build_error_message(response)
    detail = extract_error_detail(response.body)
    detail.present? ? "SAT request failed (HTTP #{response.status}): #{detail}" : "SAT request failed (HTTP #{response.status})"
  end

  def extract_error_detail(body)
    parsed = JSON.parse(body)
    parsed['detail'] if parsed.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end
end
