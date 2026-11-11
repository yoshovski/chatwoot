module AccountSubscriptionSettings
  extend ActiveSupport::Concern

  def subscription_settings
    account_subscription || build_account_subscription(quota_anchor: Time.current)
  end

  def subscription_settings=(attributes)
    subscription_settings.assign_attributes(attributes)
  end

  # An account without a subscription row is treated as a new, unconfigured manual one: no plan, so no AI.
  def ai_reply_allowed?(conversation = nil)
    (account_subscription || AccountSubscription.new(account: self)).ai_reply_allowed?(conversation)
  end
end
