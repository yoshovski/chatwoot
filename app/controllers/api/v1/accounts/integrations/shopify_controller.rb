class Api::V1::Accounts::Integrations::ShopifyController < Api::V1::Accounts::Integrations::BaseController
  include Shopify::IntegrationHelper
  before_action :setup_shopify_context, only: [:orders]
  before_action :fetch_hook, only: [:orders, :destroy, :sync_status, :pause_catalog, :resume_catalog]
  before_action :check_authorization, only: [:destroy]
  before_action :validate_contact, only: [:orders]

  def show
    hook = Integrations::Hook.find_by(account: Current.account, app_id: 'shopify')
    render json: hook_payload(hook)
  end

  def request_connection
    shop_domain = Shopify::ShopDomain.normalize(params[:shop_domain])
    unless Shopify::ShopDomain.valid?(shop_domain)
      return render json: { error: 'Please enter a valid Shopify store URL (e.g. your-store.myshopify.com)' },
                    status: :unprocessable_entity
    end

    hook = Integrations::Hook.find_or_initialize_by(account: Current.account, app_id: 'shopify')
    hook.reference_id = shop_domain
    hook.status = :disabled
    hook.settings = hook.settings.to_h.merge(
      'state' => 'requested',
      'shop_domain' => shop_domain,
      'requested_at' => Time.current.iso8601
    )
    hook.save!

    render json: hook_payload(hook)
  end

  def sync_status
    catalog_status = refresh_sat_state_and_catalog if @hook.shopify_sat_tenant_id.present?
    render json: hook_payload(@hook, catalog_status_data: catalog_status)
  rescue ShopifyAgentTools::AdminClient::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def pause_catalog
    if @hook.shopify_sat_tenant_id.present?
      sat_client = ShopifyAgentTools::AdminClient.new
      sat_client.pause_catalog_sync(@hook.shopify_sat_tenant_id)
      @hook.settings = @hook.settings.to_h.merge('catalog_sync_enabled' => false)
      @hook.save!
    end

    render json: hook_payload(@hook)
  rescue ShopifyAgentTools::AdminClient::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def resume_catalog
    if @hook.shopify_sat_tenant_id.present?
      sat_client = ShopifyAgentTools::AdminClient.new
      sat_client.resume_catalog_sync(@hook.shopify_sat_tenant_id)
      @hook.settings = @hook.settings.to_h.merge('catalog_sync_enabled' => true)
      @hook.save!
    end

    render json: hook_payload(@hook)
  rescue ShopifyAgentTools::AdminClient::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def auth
    shop_domain = params[:shop_domain]
    return render json: { error: 'Shop domain is required' }, status: :unprocessable_entity if shop_domain.blank?

    state = generate_shopify_token(Current.account.id)

    auth_url = "https://#{shop_domain}/admin/oauth/authorize?"
    auth_url += URI.encode_www_form(
      client_id: client_id,
      scope: REQUIRED_SCOPES.join(','),
      redirect_uri: redirect_uri,
      state: state
    )

    render json: { redirect_url: auth_url }
  end

  def orders
    return render json: { orders: [], disabled: true } if @hook.shopify_sat_managed?

    customers = fetch_customers
    return render json: { orders: [] } if customers.empty?

    orders = fetch_orders(customers.first['id'])
    render json: { orders: orders }
  rescue ShopifyAPI::Errors::HttpResponseError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    if @hook.shopify_sat_tenant_id.present?
      begin
        ShopifyAgentTools::AdminClient.new.delete_tenant(@hook.shopify_sat_tenant_id)
      rescue ShopifyAgentTools::AdminClient::Error => e
        Rails.logger.warn("[Shopify] Failed to delete SAT tenant #{@hook.shopify_sat_tenant_id}: #{e.message}")
      end
    end

    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/shopify/callback"
  end

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'shopify')
  end

  def fetch_customers
    query = []
    query << "email:#{contact.email}" if contact.email.present?
    query << "phone:#{contact.phone_number}" if contact.phone_number.present?

    shopify_client.get(
      path: 'customers/search.json',
      query: {
        query: query.join(' OR '),
        fields: 'id,email,phone'
      }
    ).body['customers'] || []
  end

  def fetch_orders(customer_id)
    orders = shopify_client.get(
      path: 'orders.json',
      query: {
        customer_id: customer_id,
        status: 'any',
        fields: 'id,email,created_at,total_price,currency,fulfillment_status,financial_status'
      }
    ).body['orders'] || []

    orders.map do |order|
      order.merge('admin_url' => "https://#{@hook.reference_id}/admin/orders/#{order['id']}")
    end
  end

  def setup_shopify_context
    return if client_id.blank? || client_secret.blank?

    ShopifyAPI::Context.setup(
      api_key: client_id,
      api_secret_key: client_secret,
      api_version: '2025-01'.freeze,
      scope: REQUIRED_SCOPES.join(','),
      is_embedded: true,
      is_private: false
    )
  end

  def shopify_session
    ShopifyAPI::Auth::Session.new(shop: @hook.reference_id, access_token: @hook.access_token)
  end

  def shopify_client
    @shopify_client ||= ShopifyAPI::Clients::Rest::Admin.new(session: shopify_session)
  end

  def validate_contact
    return unless contact.blank? || (contact.email.blank? && contact.phone_number.blank?)

    render json: { error: 'Contact information missing' },
           status: :unprocessable_entity
  end

  def hook_payload(hook, catalog_status_data: nil)
    return { id: nil, state: 'disconnected', enabled: false, catalog_status: nil } if hook.nil?

    payload = {
      id: hook.id,
      state: hook.shopify_state,
      shop_domain: hook.reference_id,
      storefront_url: hook.shopify_storefront_url,
      install_url: hook.settings.to_h['install_url'],
      sat_tenant_id: hook.shopify_sat_tenant_id,
      catalog_dataset_id: hook.shopify_catalog_dataset_id,
      catalog_status: hook.shopify_catalog_client_status(catalog_status_data),
      catalog_sync_enabled: hook.shopify_catalog_sync_enabled?,
      enabled: hook.enabled?,
      approved_at: hook.settings.to_h['approved_at'],
      requested_at: hook.settings.to_h['requested_at']
    }
    payload.merge(hook: payload)
  end

  def refresh_sat_state_and_catalog
    sat_client = ShopifyAgentTools::AdminClient.new
    apply_sat_status(sat_client.tenant(@hook.shopify_sat_tenant_id))
    ensure_catalog_provisioned(sat_client) if @hook.shopify_connected? && @hook.shopify_catalog_dataset_id.blank?
    status = fetch_catalog_status(sat_client)
    @hook.save!
    status
  end

  def fetch_catalog_status(sat_client)
    status = sat_client.catalog_status(@hook.shopify_sat_tenant_id)
    return unless status

    @hook.settings = @hook.settings.to_h.merge('catalog_sync_enabled' => status['sync_enabled'] != false)
    if status['documents_failed'].to_i.positive?
      Rails.logger.warn("[Shopify Catalog] Tenant #{@hook.shopify_sat_tenant_id} has #{status['documents_failed']} failed products")
    end
    status
  rescue ShopifyAgentTools::AdminClient::Error => e
    Rails.logger.info("[Shopify] Catalog status query skipped: #{e.message}")
    nil
  end

  def ensure_catalog_provisioned(sat_client)
    return @hook.shopify_catalog_dataset_id if @hook.shopify_catalog_dataset_id.present?
    return unless @hook.shopify_sat_tenant_id.present? && @hook.shopify_connected?

    dataset = provision_or_fetch_dataset(sat_client)
    attach_catalog_dataset(dataset, sat_client)
    @hook.shopify_catalog_dataset_id
  end

  def provision_or_fetch_dataset(sat_client)
    sat_client.provision_dify_dataset(@hook.shopify_sat_tenant_id)
  rescue ShopifyAgentTools::AdminClient::Error => e
    raise unless e.status == 409

    sat_client.dify_dataset(@hook.shopify_sat_tenant_id)
  end

  def attach_catalog_dataset(dataset, sat_client)
    return unless dataset && dataset['dataset_id'].present?

    @hook.settings = @hook.settings.to_h.merge(
      'catalog_dataset_id' => dataset['dataset_id'],
      'catalog_sync_enabled' => dataset['sync_enabled'] != false
    )
    trigger_catalog_import(sat_client)
  end

  def trigger_catalog_import(sat_client)
    sat_client.start_catalog_import(@hook.shopify_sat_tenant_id)
  rescue ShopifyAgentTools::AdminClient::Error => e
    Rails.logger.warn("[Shopify Catalog] Import start failed: #{e.message}")
  end

  def apply_sat_status(tenant)
    status = tenant['status'].to_s
    shopify_state = tenant.dig('shopify_connection', 'state').to_s

    if status == 'connected' || shopify_state == 'connected'
      @hook.settings = @hook.settings.to_h.merge(
        'state' => 'connected',
        'storefront_url' => tenant['storefront_base_url'].presence || @hook.shopify_storefront_url
      )
      @hook.status = :enabled
    elsif status == 'importing'
      @hook.settings = @hook.settings.to_h.merge('state' => 'importing')
    elsif %w[reauthorization_required uninstalled].include?(status) || %w[reauthorization_required uninstalled].include?(shopify_state)
      @hook.settings = @hook.settings.to_h.merge('state' => 'needs_reconnect')
      @hook.status = :disabled
    end
  end
end
