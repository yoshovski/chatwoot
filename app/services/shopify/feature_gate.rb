class Shopify::FeatureGate
  ACCOUNT_FEATURE = 'shopify_integration'.freeze
  GLOBAL_CONFIG = 'ENABLE_SHOPIFY_INTEGRATION'.freeze

  # App Store OAuth, Shopify webhooks and Shopify billing need the installation switch as well.
  def self.enabled?(account: nil)
    return false unless globally_enabled?

    account.nil? || account.feature_enabled?(ACCOUNT_FEATURE)
  end

  # The custom-app connection through Shopify Agent Tools needs neither the Partner app nor the
  # installation switch, so the workspace switch in Super Admin alone controls it.
  def self.workspace_enabled?(account)
    account.feature_enabled?(ACCOUNT_FEATURE)
  end

  def self.globally_enabled?
    configured_value = GlobalConfigService.load(GLOBAL_CONFIG, 'false')
    ActiveModel::Type::Boolean.new.cast(configured_value)
  end
end
