# Decides how a mobile (FCM) push subscription is delivered.
#
# Our own mobile apps register with an `app_id` and are sent through this installation's
# Firebase project. The official Chatwoot app registers without one; its tokens belong to
# Chatwoot's Firebase project, so they can only be reached through Chatwoot's push relay,
# even when this installation has Firebase credentials of its own.
class Notification::PushRoute
  DEFAULT_OWN_APP_IDS = 'com.chatoctave.app'.freeze

  def self.for(subscription)
    new(subscription).route
  end

  def self.firebase_credentials_present?
    GlobalConfigService.load('FIREBASE_PROJECT_ID', nil).present? &&
      GlobalConfigService.load('FIREBASE_CREDENTIALS', nil).present?
  end

  def self.relay_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_PUSH_RELAY_SERVER', true))
  end

  def self.own_app_ids
    ENV.fetch('OWN_MOBILE_APP_IDS', DEFAULT_OWN_APP_IDS).split(',').map(&:strip).compact_blank
  end

  def initialize(subscription)
    @subscription = subscription
  end

  # :own_firebase, :chatwoot_relay or :none
  def route
    return :none unless @subscription.fcm?
    return own_app_route if own_app?

    self.class.relay_enabled? ? :chatwoot_relay : :none
  end

  private

  def own_app?
    self.class.own_app_ids.include?(@subscription.subscription_attributes&.dig('app_id').to_s)
  end

  def own_app_route
    return :own_firebase if self.class.firebase_credentials_present?

    Rails.logger.warn(
      "Push subscription #{@subscription.id} (app #{@subscription.subscription_attributes['app_id']}) skipped: " \
      'FIREBASE_PROJECT_ID / FIREBASE_CREDENTIALS are not set and the Chatwoot relay cannot deliver to this app'
    )
    :none
  end
end
