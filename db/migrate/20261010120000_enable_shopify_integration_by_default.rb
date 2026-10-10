class EnableShopifyIntegrationByDefault < ActiveRecord::Migration[7.0]
  def up
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    if config && config.value.present?
      config.value = config.value.map { |f| f['name'] == 'shopify_integration' ? f.merge('enabled' => true) : f }
      config.save!
    end

    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.enable_features!('shopify_integration') }
    end

    GlobalConfig.clear_cache
  end
end
