# == Schema Information
#
# Table name: integrations_hooks
#
#  id           :bigint           not null, primary key
#  access_token :string
#  hook_type    :integer          default("account")
#  settings     :jsonb
#  status       :integer          default("enabled")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :integer
#  app_id       :string
#  inbox_id     :integer
#  reference_id :string
#
class Integrations::Hook < ApplicationRecord # rubocop:disable Metrics/ClassLength
  include Reauthorizable

  attr_readonly :app_id, :account_id, :inbox_id, :hook_type
  before_validation :ensure_hook_type, on: :create
  before_validation :normalize_shopify_reference_id, if: :shopify?
  after_create :trigger_setup_if_crm

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  encrypts :access_token, deterministic: true if Chatwoot.encryption_configured?

  validates :account_id, presence: true
  validates :app_id, presence: true
  validates :inbox_id, presence: true, if: -> { hook_type == 'inbox' }
  validates :reference_id, presence: true, format: { with: Shopify::ShopDomain::FORMAT }, if: :shopify?
  validates :reference_id,
            uniqueness: { case_sensitive: false, conditions: -> { where(app_id: 'shopify') } },
            if: :shopify?
  validate :validate_settings_json_schema
  validate :ensure_feature_enabled
  validate :validate_openai_api_key, if: :validate_openai_api_key?
  validate :validate_cloudflare_realtimekit_credentials, if: :validate_cloudflare_realtimekit_credentials?
  validates :app_id, uniqueness: { scope: [:account_id], unless: -> { app.present? && app.params[:allow_multiple_hooks].present? } }

  # TODO: This seems to be only used for slack at the moment
  # We can add a validator when storing the integration settings and toggle this in future
  enum status: { disabled: 0, enabled: 1 }

  belongs_to :account
  belongs_to :inbox, optional: true
  has_secure_token :access_token

  enum hook_type: { account: 0, inbox: 1 }

  scope :account_hooks, -> { where(hook_type: 'account') }
  scope :inbox_hooks, -> { where(hook_type: 'inbox') }

  def app
    @app ||= Integrations::App.find(id: app_id)
  end

  def slack?
    app_id == 'slack'
  end

  # Alert mode makes the Slack integration one way. Conversations are pushed to Slack,
  # but replies posted in the Slack thread are never synced back to the customer.
  def slack_alert_mode?
    slack? && settings['message_mode'] == 'alert'
  end

  def dialogflow?
    app_id == 'dialogflow'
  end

  def openai?
    app_id == 'openai'
  end

  def dyte?
    app_id == 'dyte'
  end

  def notion?
    app_id == 'notion'
  end

  def shopify?
    app_id == 'shopify'
  end

  def shopify_state
    return nil unless shopify?

    settings.to_h['state'].presence || (enabled? ? 'connected' : 'disconnected')
  end

  def shopify_sat_tenant_id
    return nil unless shopify?

    settings.to_h['sat_tenant_id']
  end

  def shopify_storefront_url
    return nil unless shopify?

    settings.to_h['storefront_url'].presence || (reference_id.present? ? "https://#{reference_id}" : nil)
  end

  def shopify_sat_managed?
    shopify? && (settings.to_h['sat_tenant_id'].present? || settings.to_h['state'].present?)
  end

  def shopify_connected?
    shopify? && shopify_state == 'connected'
  end

  def shopify_catalog_dataset_id
    return nil unless shopify?

    settings.to_h['catalog_dataset_id']
  end

  def shopify_catalog_dataset_id=(value)
    return unless shopify?

    self.settings = settings.to_h.merge('catalog_dataset_id' => value.presence)
  end

  def shopify_catalog_sync_enabled?
    return false unless shopify?

    settings.to_h.fetch('catalog_sync_enabled', true) != false
  end

  def shopify_catalog_client_status(sat_status = nil)
    return nil unless shopify?
    return 'needs_reconnect' if shopify_state == 'needs_reconnect'
    return 'importing' if shopify_state == 'importing'
    return 'off' unless shopify_connected?

    status_from_sat(sat_status) || fallback_catalog_status
  end

  def shopify_tool_key
    return nil unless shopify?

    encrypted = settings.to_h['encrypted_tool_key']
    return nil if encrypted.blank?

    self.class.decrypt_shopify_tool_key(encrypted)
  end

  def shopify_tool_key=(value)
    return unless shopify?

    self.settings = settings.to_h.merge('encrypted_tool_key' => value.present? ? self.class.encrypt_shopify_tool_key(value) : nil)
  end

  def self.encrypt_shopify_tool_key(value)
    shopify_tool_key_encryptor.encrypt_and_sign(value)
  end

  def self.decrypt_shopify_tool_key(encrypted_value)
    shopify_tool_key_encryptor.decrypt_and_verify(encrypted_value)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def self.shopify_tool_key_encryptor
    @shopify_tool_key_encryptor ||= begin
      key_generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
      key = key_generator.generate_key('shopify_sat_tool_key', 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm')
    end
  end

  def disable
    update(status: 'disabled')
  end

  def process_event(_event)
    # OpenAI integration migrated to Captain::EditorService
    # Other integrations (slack, dialogflow, etc.) handled via HookJob
    { error: 'No processor found' }
  end

  def feature_allowed?
    return true if app.blank?

    flag = app.params[:feature_flag]
    return true unless flag

    account.feature_enabled?(flag)
  end

  private

  def status_from_sat(sat_status)
    return unless sat_status.is_a?(Hash)

    log_failed_products(sat_status)
    return 'off' if sat_status['sync_enabled'] == false
    return 'importing' if sat_importing?(sat_status)
    return 'on' if sat_status['sync_enabled'] == true && (sat_status['configured'] == true || shopify_catalog_dataset_id.present?)

    nil
  end

  def sat_importing?(sat_status)
    sat_status['documents_synced'].to_i.zero? &&
      (sat_status['processing_jobs'].to_i.positive? || sat_status['queued_jobs'].to_i.positive? || sat_status['active_job_kind'].present?)
  end

  def log_failed_products(sat_status)
    return unless sat_status['documents_failed'].to_i.positive?

    Rails.logger.warn("[Shopify Catalog] Tenant #{shopify_sat_tenant_id} has #{sat_status['documents_failed']} failed products during sync")
  end

  def fallback_catalog_status
    return 'off' unless shopify_catalog_sync_enabled?

    shopify_catalog_dataset_id.present? ? 'on' : 'importing'
  end

  def ensure_feature_enabled
    return if shopify? && disabled?

    errors.add(:feature_flag, 'Feature not enabled') unless feature_allowed?
  end

  def ensure_hook_type
    return if app.blank?

    self.hook_type = app.params[:hook_type]
  end

  def normalize_shopify_reference_id
    self.reference_id = Shopify::ShopDomain.normalize(reference_id)
  end

  def validate_settings_json_schema
    return if app.blank? || app.params[:settings_json_schema].blank?
    return if legacy_dyte_settings_unchanged?

    errors.add(:settings, ': Invalid settings data') unless JSONSchemer.schema(app.params[:settings_json_schema]).valid?(settings)
  end

  # TODO: When adding credential validation for other integrations (dialogflow, dyte, etc.),
  # extract this into an app-level config flag in apps.yml instead of hardcoding app_id checks.
  def validate_openai_api_key?
    openai? && enabled? && (new_record? || openai_api_key_changed? || will_save_change_to_status?)
  end

  def validate_cloudflare_realtimekit_credentials?
    dyte? && enabled? && !legacy_dyte_settings_unchanged? &&
      (new_record? || cloudflare_realtimekit_credentials_changed? || will_save_change_to_status?)
  end

  def openai_api_key_changed?
    settings_api_key(settings) != settings_api_key(settings_in_database)
  end

  def cloudflare_realtimekit_credentials_changed?
    settings_cloudflare_realtimekit_credentials(settings) != settings_cloudflare_realtimekit_credentials(settings_in_database)
  end

  def legacy_dyte_settings_unchanged?
    dyte? && persisted? && !will_save_change_to_settings? && legacy_dyte_settings?(settings_in_database)
  end

  def legacy_dyte_settings?(value)
    return false if value.blank?

    %w[organization_id api_key].any? { |key| settings_value(value, key).present? } &&
      %w[account_id app_id api_token].none? { |key| settings_value(value, key).present? }
  end

  def validate_openai_api_key
    return if Integrations::Openai::KeyValidator.valid?(settings_api_key(settings))

    errors.add(:base, I18n.t('errors.openai.invalid_api_key'))
  end

  def validate_cloudflare_realtimekit_credentials
    result = Integrations::Cloudflare::RealtimeKitCredentialsValidator.validate(*settings_cloudflare_realtimekit_credentials(settings))
    return if result.success?

    errors.add(:base, I18n.t("errors.cloudflare.realtimekit.#{result.error}"))
  end

  def settings_api_key(value)
    settings_value(value, 'api_key')
  end

  def settings_cloudflare_realtimekit_credentials(value)
    [
      settings_value(value, 'account_id'),
      settings_value(value, 'app_id'),
      settings_value(value, 'api_token')
    ]
  end

  def settings_value(value, key)
    value&.dig(key) || value&.dig(key.to_sym)
  end

  def trigger_setup_if_crm
    # we need setup services to create data prerequisite to functioning of the integration
    # in case of Leadsquared, we need to create a custom activity type for capturing conversations and transcripts
    # https://apidocs.leadsquared.com/create-new-activity-type-api/
    return unless crm_integration?

    ::Crm::SetupJob.perform_later(id)
  end

  def crm_integration?
    %w[leadsquared].include?(app_id)
  end
end
