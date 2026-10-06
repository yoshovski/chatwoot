class SuperAdmin::ShopifyRequestsController < SuperAdmin::ApplicationController
  before_action :fetch_hook, only: [:show, :approve, :sync_status, :rotate_tool_key]

  def index
    @hooks = Integrations::Hook.where(app_id: 'shopify').includes(:account).order(created_at: :desc)
  end

  def show
    return if @hook.shopify_sat_tenant_id.blank?

    begin
      @sat_tenant = sat_client.tenant(@hook.shopify_sat_tenant_id)
    rescue ShopifyAgentTools::AdminClient::Error => e
      @sat_error = e.message
    end
  end

  def approve
    return redirect_with_alert('credentials_required') if credentials_blank?

    tenant_id = ensure_sat_tenant_id
    config = sat_client.configure_shopify(tenant_id, client_id: client_id, client_secret: client_secret, storefront_base_url: storefront_base_url)
    update_hook_on_approval(tenant_id, config['install_url'])

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.approved')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  def sync_status
    if @hook.shopify_sat_tenant_id.present?
      tenant = sat_client.tenant(@hook.shopify_sat_tenant_id)
      apply_tenant_sync(tenant)
      @hook.save!
    end

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.status_synced')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  def rotate_tool_key
    if @hook.shopify_sat_tenant_id.present?
      result = sat_client.rotate_tool_key(@hook.shopify_sat_tenant_id)
      @hook.shopify_tool_key = result['tool_key']
      @hook.save!
    end

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.tool_key_rotated')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  private

  def sat_client
    @sat_client ||= ShopifyAgentTools::AdminClient.new
  end

  def client_id
    params[:client_id].to_s.strip
  end

  def client_secret
    params[:client_secret].to_s.strip
  end

  def storefront_base_url
    params[:storefront_base_url].to_s.strip.presence || "https://#{@hook.reference_id}"
  end

  def credentials_blank?
    client_id.blank? || client_secret.blank?
  end

  def redirect_with_alert(key)
    redirect_to super_admin_shopify_request_path(@hook), alert: I18n.t("super_admin.shopify_requests.#{key}")
  end

  def ensure_sat_tenant_id
    return @hook.shopify_sat_tenant_id if @hook.shopify_sat_tenant_id.present?

    tenant = sat_client.create_tenant(
      name: "#{@hook.account.name} (Shopify)",
      slug: "chatwoot-acc-#{@hook.account_id}-#{@hook.id}",
      shop_domain: @hook.reference_id
    )
    @hook.shopify_tool_key = tenant['tool_key']
    tenant['id']
  end

  def update_hook_on_approval(tenant_id, install_url)
    @hook.settings = @hook.settings.to_h.merge(
      'sat_tenant_id' => tenant_id,
      'install_url' => install_url,
      'storefront_url' => storefront_base_url,
      'state' => 'pending_install',
      'approved_by_id' => current_super_admin.id,
      'approved_by_email' => current_super_admin.email,
      'approved_at' => Time.current.iso8601
    )
    @hook.save!
  end

  def apply_tenant_sync(tenant)
    status = tenant['status'].to_s
    shopify_state = tenant.dig('shopify_connection', 'state').to_s

    if status == 'connected' || shopify_state == 'connected'
      mark_hook_connected(tenant)
    elsif status == 'importing'
      @hook.settings = @hook.settings.to_h.merge('state' => 'importing')
    elsif disconnected_state?(status, shopify_state)
      mark_hook_needs_reconnect
    end
  end

  def mark_hook_connected(tenant)
    @hook.settings = @hook.settings.to_h.merge(
      'state' => 'connected',
      'storefront_url' => tenant['storefront_base_url'].presence || @hook.shopify_storefront_url
    )
    @hook.status = :enabled
  end

  def mark_hook_needs_reconnect
    @hook.settings = @hook.settings.to_h.merge('state' => 'needs_reconnect')
    @hook.status = :disabled
  end

  def disconnected_state?(status, shopify_state)
    %w[reauthorization_required uninstalled].include?(status) ||
      %w[reauthorization_required uninstalled].include?(shopify_state)
  end

  def fetch_hook
    @hook = Integrations::Hook.where(app_id: 'shopify').find(params[:id])
  end
end
