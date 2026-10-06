class Api::V1::Accounts::Integrations::ShopifyController < Api::V1::Accounts::Integrations::BaseController
  include Shopify::IntegrationHelper
  before_action :setup_shopify_context, only: [:orders]
  before_action :fetch_hook, only: [:orders, :destroy, :sync_status]
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
    if @hook.shopify_sat_tenant_id.present?
      sat_client = ShopifyAgentTools::AdminClient.new
      tenant = sat_client.tenant(@hook.shopify_sat_tenant_id)
      apply_sat_status(tenant)
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

  def hook_payload(hook)
    return { id: nil, state: 'disconnected', enabled: false } if hook.nil?

    {
      id: hook.id,
      state: hook.shopify_state,
      shop_domain: hook.reference_id,
      storefront_url: hook.shopify_storefront_url,
      install_url: hook.settings.to_h['install_url'],
      sat_tenant_id: hook.shopify_sat_tenant_id,
      enabled: hook.enabled?,
      approved_at: hook.settings.to_h['approved_at'],
      requested_at: hook.settings.to_h['requested_at']
    }
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
