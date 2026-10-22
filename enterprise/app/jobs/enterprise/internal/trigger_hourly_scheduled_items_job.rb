module Enterprise::Internal::TriggerHourlyScheduledItemsJob
  def perform
    super

    Captain::Knowledge::RefreshBriefsJob.perform_later

    return unless Shopify::FeatureGate.globally_enabled?

    Enterprise::Billing::ShopifySubscriptionReconciliationJob.perform_later
  end
end
