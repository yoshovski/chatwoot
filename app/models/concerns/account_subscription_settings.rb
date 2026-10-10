module AccountSubscriptionSettings
  extend ActiveSupport::Concern

  def subscription_settings
    account_subscription || build_account_subscription(quota_anchor: Time.current)
  end

  def subscription_settings=(attributes)
    subscription_settings.assign_attributes(attributes)
  end

  def ai_reply_allowed?(conversation = nil)
    account_subscription.nil? || account_subscription.ai_reply_allowed?(conversation)
  end
end
