class Notification::PushNotificationService
  include Rails.application.routes.url_helpers

  pattr_initialize [:notification!]

  def perform
    return unless user_subscribed_to_notification?

    notification_subscriptions.each do |subscription|
      send_browser_push(subscription)
      send_mobile_push(subscription)
    end
  end

  private

  delegate :user, to: :notification
  delegate :notification_subscriptions, to: :user
  delegate :notification_settings, to: :user

  def user_subscribed_to_notification?
    notification_setting = notification_settings.find_by(account_id: notification.account.id)
    return true if notification_setting.public_send("push_#{notification.notification_type}?")

    false
  end

  def conversation
    @conversation ||= notification.conversation
  end

  def push_message
    {
      title: notification.push_message_title,
      tag: "#{notification.notification_type}_#{conversation.display_id}_#{notification.id}",
      url: push_url
    }
  end

  def push_url
    app_account_conversation_url(account_id: conversation.account_id, id: conversation.display_id)
  end

  def can_send_browser_push?(subscription)
    VapidService.public_key && subscription.browser_push?
  end

  def browser_push_payload(subscription)
    {
      message: JSON.generate(push_message),
      endpoint: subscription.subscription_attributes['endpoint'],
      p256dh: subscription.subscription_attributes['p256dh'],
      auth: subscription.subscription_attributes['auth'],
      vapid: {
        subject: push_url,
        public_key: VapidService.public_key,
        private_key: VapidService.private_key
      },
      ssl_timeout: 5,
      open_timeout: 5,
      read_timeout: 5
    }
  end

  def send_browser_push(subscription)
    return unless can_send_browser_push?(subscription)

    WebPush.payload_send(**browser_push_payload(subscription))
    Rails.logger.info("Browser push sent to #{user.email} with title #{push_message[:title]}")
  rescue StandardError => e
    handle_browser_push_error(e, subscription)
  end

  def handle_browser_push_error(error, subscription)
    case error
    when WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
      Rails.logger.info "WebPush subscription expired: #{error.message}"
      subscription.destroy!
    when WebPush::TooManyRequests
      Rails.logger.warn "WebPush rate limited for #{user.email} on account #{notification.account.id}: #{error.message}"
    when Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, Socket::ResolutionError
      Rails.logger.error "WebPush operation error: #{error.message}"
    else
      ChatwootExceptionTracker.new(error, account: notification.account).capture_exception
      true
    end
  end

  def send_mobile_push(subscription)
    case Notification::PushRoute.for(subscription)
    when :own_firebase then send_fcm_push(subscription)
    when :chatwoot_relay then ChatwootHub.send_push(fcm_options(subscription))
    end
  end

  def send_fcm_push(subscription)
    fcm_service = Notification::FcmService.new(
      GlobalConfigService.load('FIREBASE_PROJECT_ID', nil), GlobalConfigService.load('FIREBASE_CREDENTIALS', nil)
    )
    response = fcm_service.fcm_client.send_v1(fcm_options(subscription))
    handle_fcm_response(subscription, response)
  end

  # FCM v1 errors: https://firebase.google.com/docs/reference/fcm/rest/v1/ErrorCode
  # Only a token FCM reports as gone is deleted. SENDER_ID_MISMATCH means the token belongs to
  # another Firebase project (a routing or config mistake), so the subscription is kept.
  def handle_fcm_response(subscription, response)
    status_code = response[:status_code].to_i
    return Rails.logger.info("FCM push sent to #{user.email} with title #{push_message[:title]}") if status_code.between?(200, 299)

    error_code, error_message = fcm_error(response)
    if dead_fcm_token?(error_code, error_message)
      Rails.logger.info("FCM token for subscription #{subscription.id} is no longer valid (#{error_code}), removing it")
      subscription.destroy!
    else
      Rails.logger.warn("FCM push failed for subscription #{subscription.id} (app #{subscription.subscription_attributes['app_id'] || 'none'}): " \
                        "HTTP #{status_code} #{error_code} #{error_message}")
    end
  end

  def fcm_error(response)
    error = JSON.parse(response[:body].presence || '{}')['error'] || {}
    error_code = error['details']&.find { |detail| detail['errorCode'] }&.dig('errorCode') || error['status']
    [error_code, error['message'].to_s]
  end

  def dead_fcm_token?(error_code, error_message)
    error_code == 'UNREGISTERED' || (error_code == 'INVALID_ARGUMENT' && error_message.match?(/registration token/i))
  end

  def fcm_options(subscription)
    {
      'token': subscription.subscription_attributes['push_token'],
      'data': fcm_data,
      'notification': fcm_notification,
      'android': fcm_android_options,
      'apns': fcm_apns_options,
      'fcm_options': {
        analytics_label: 'Label'
      }
    }
  end

  def fcm_data
    {
      payload: {
        data: {
          notification: notification.fcm_push_data
        }
      }.to_json
    }
  end

  def fcm_notification
    {
      title: notification.push_message_title,
      body: notification.push_message_body
    }
  end

  def fcm_android_options
    {
      priority: 'high'
    }
  end

  def fcm_apns_options
    {
      payload: {
        aps: {
          sound: 'default',
          category: Time.zone.now.to_i.to_s
        }
      }
    }
  end
end
