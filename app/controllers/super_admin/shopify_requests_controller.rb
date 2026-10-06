class SuperAdmin::ShopifyRequestsController < SuperAdmin::ApplicationController # rubocop:disable Metrics/ClassLength
  before_action :fetch_hook,
                only: [
                  :show, :approve, :sync_status, :rotate_tool_key,
                  :provision_catalog, :import_catalog, :pause_catalog, :resume_catalog
                ]

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

    begin
      @catalog_status = sat_client.catalog_status(@hook.shopify_sat_tenant_id)
    rescue ShopifyAgentTools::AdminClient::Error => e
      @catalog_error = e.message
    end
  end

  def approve
    return redirect_with_alert('credentials_required') if credentials_blank?

    tenant_id = ensure_sat_tenant_id
    config = sat_client.configure_shopify(
      tenant_id,
      shop_domain: @hook.reference_id,
      client_id: client_id,
      client_secret: client_secret,
      storefront_base_url: storefront_base_url
    )
    update_hook_on_approval(tenant_id, config['install_url'])

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.approved')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  def sync_status
    refresh_sat_state_and_catalog if @hook.shopify_sat_tenant_id.present?

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.status_synced')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  def provision_catalog
    if @hook.shopify_sat_tenant_id.present?
      ensure_catalog_provisioned
      @hook.save!
    end

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.catalog_provisioned')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  def import_catalog
    sat_client.start_catalog_import(@hook.shopify_sat_tenant_id) if @hook.shopify_sat_tenant_id.present?

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.catalog_imported')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  def pause_catalog
    if @hook.shopify_sat_tenant_id.present?
      sat_client.pause_catalog_sync(@hook.shopify_sat_tenant_id)
      @hook.settings = @hook.settings.to_h.merge('catalog_sync_enabled' => false)
      @hook.save!
    end

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.catalog_paused')
  rescue ShopifyAgentTools::AdminClient::Error => e
    redirect_to super_admin_shopify_request_path(@hook), alert: "Shopify Agent Tools error: #{e.message}"
  end

  def resume_catalog
    if @hook.shopify_sat_tenant_id.present?
      sat_client.resume_catalog_sync(@hook.shopify_sat_tenant_id)
      @hook.settings = @hook.settings.to_h.merge('catalog_sync_enabled' => true)
      @hook.save!
    end

    redirect_to super_admin_shopify_request_path(@hook), notice: I18n.t('super_admin.shopify_requests.catalog_resumed')
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

  def refresh_sat_state_and_catalog
    tenant = sat_client.tenant(@hook.shopify_sat_tenant_id)
    apply_tenant_sync(tenant)
    ensure_catalog_provisioned if @hook.shopify_connected? && @hook.shopify_catalog_dataset_id.blank?
    sync_catalog_status
    @hook.save!
  end

  def sync_catalog_status
    status = sat_client.catalog_status(@hook.shopify_sat_tenant_id)
    return unless status

    @hook.settings = @hook.settings.to_h.merge('catalog_sync_enabled' => status['sync_enabled'] != false)
    if status['documents_failed'].to_i.positive?
      Rails.logger.warn("[Shopify Catalog] Tenant #{@hook.shopify_sat_tenant_id} has #{status['documents_failed']} failed products")
    end
  rescue ShopifyAgentTools::AdminClient::Error => e
    Rails.logger.info("[Shopify] Catalog status sync skipped: #{e.message}")
  end

  def ensure_catalog_provisioned
    return @hook.shopify_catalog_dataset_id if @hook.shopify_catalog_dataset_id.present?
    return if @hook.shopify_sat_tenant_id.blank?

    dataset = provision_or_fetch_dataset
    attach_catalog_dataset(dataset)
    @hook.shopify_catalog_dataset_id
  end

  def provision_or_fetch_dataset
    sat_client.provision_dify_dataset(@hook.shopify_sat_tenant_id)
  rescue ShopifyAgentTools::AdminClient::Error => e
    raise unless e.status == 409

    sat_client.dify_dataset(@hook.shopify_sat_tenant_id)
  end

  def attach_catalog_dataset(dataset)
    return unless dataset && dataset['dataset_id'].present?

    @hook.settings = @hook.settings.to_h.merge(
      'catalog_dataset_id' => dataset['dataset_id'],
      'catalog_sync_enabled' => dataset['sync_enabled'] != false
    )
    trigger_catalog_import
  end

  def trigger_catalog_import
    sat_client.start_catalog_import(@hook.shopify_sat_tenant_id)
  rescue ShopifyAgentTools::AdminClient::Error => e
    Rails.logger.warn("[Shopify Catalog] Import start failed: #{e.message}")
  end

  def fetch_hook
    @hook = Integrations::Hook.where(app_id: 'shopify').find(params[:id])
  end
end
