require 'rails_helper'

describe Notification::PushNotificationService do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:notification) { create(:notification, user: user, account: user.accounts.first) }
  let(:fcm_double) { instance_double(FCM) }
  let(:fcm_service_double) { instance_double(Notification::FcmService, fcm_client: fcm_double) }

  describe '#perform' do
    context 'when the push server returns success' do
      before do
        allow(WebPush).to receive(:payload_send).and_return(true)
        allow(Rails.logger).to receive(:info)
        allow(Notification::FcmService).to receive(:new).and_return(fcm_service_double)
        allow(fcm_double).to receive(:send_v1).and_return({ body: { name: 'projects/test/messages/1' }.to_json, status_code: 200 })
        allow(GlobalConfigService).to receive(:load).with('FIREBASE_PROJECT_ID', nil).and_return('test_project_id')
        allow(GlobalConfigService).to receive(:load).with('FIREBASE_CREDENTIALS', nil).and_return('test_credentials')
      end

      it 'sends webpush notifications for webpush subscription' do
        with_modified_env VAPID_PUBLIC_KEY: 'test' do
          create(:notification_subscription, user: notification.user)

          described_class.new(notification: notification).perform
          expect(WebPush).to have_received(:payload_send)
          expect(Notification::FcmService).not_to have_received(:new)
          expect(Rails.logger).to have_received(:info).with("Browser push sent to #{user.email} with title #{notification.push_message_title}")
        end
      end

      # Only our own apps (app_id in OWN_MOBILE_APP_IDS) use the installation's Firebase project.
      it 'sends a fcm notification for firebase subscription' do
        with_modified_env ENABLE_PUSH_RELAY_SERVER: 'false' do
          create(:notification_subscription, user: notification.user, subscription_type: 'fcm',
                                             subscription_attributes: { push_token: 'token', app_id: 'com.chatoctave.app' })

          described_class.new(notification: notification).perform
          expect(Notification::FcmService).to have_received(:new)
          expect(fcm_double).to have_received(:send_v1)
          expect(WebPush).not_to have_received(:payload_send)
          expect(Rails.logger).to have_received(:info).with("FCM push sent to #{user.email} with title #{notification.push_message_title}")
        end
      end

      it 'relays the official Chatwoot app through the hub even with Firebase credentials' do
        allow(ChatwootHub).to receive(:send_push)
        create(:notification_subscription, user: notification.user, subscription_type: 'fcm',
                                           subscription_attributes: { push_token: 'token', device_id: 'device' })

        described_class.new(notification: notification).perform
        expect(ChatwootHub).to have_received(:send_push).with(hash_including(token: 'token'))
        expect(Notification::FcmService).not_to have_received(:new)
      end
    end

    context 'when FCM rejects the token' do
      let!(:subscription) do
        create(:notification_subscription, user: notification.user, subscription_type: 'fcm',
                                           subscription_attributes: { push_token: 'token', app_id: 'com.chatoctave.app' })
      end

      before do
        allow(Notification::FcmService).to receive(:new).and_return(fcm_service_double)
        allow(GlobalConfigService).to receive(:load).with('FIREBASE_PROJECT_ID', nil).and_return('test_project_id')
        allow(GlobalConfigService).to receive(:load).with('FIREBASE_CREDENTIALS', nil).and_return('test_credentials')
        allow(Rails.logger).to receive(:warn)
      end

      def fcm_error(status_code, status, error_code, message = 'error')
        { status_code: status_code,
          body: { error: { code: status_code, status: status, message: message,
                           details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: error_code }] } }.to_json }
      end

      it 'removes the subscription when the token is unregistered' do
        allow(fcm_double).to receive(:send_v1).and_return(fcm_error(404, 'NOT_FOUND', 'UNREGISTERED'))

        described_class.new(notification: notification).perform
        expect(NotificationSubscription.exists?(subscription.id)).to be(false)
      end

      it 'removes the subscription when the token is not a valid registration token' do
        allow(fcm_double).to receive(:send_v1)
          .and_return(fcm_error(400, 'INVALID_ARGUMENT', 'INVALID_ARGUMENT', 'The registration token is not a valid FCM registration token'))

        described_class.new(notification: notification).perform
        expect(NotificationSubscription.exists?(subscription.id)).to be(false)
      end

      it 'keeps the subscription and warns when the token belongs to another Firebase project' do
        allow(fcm_double).to receive(:send_v1).and_return(fcm_error(403, 'PERMISSION_DENIED', 'SENDER_ID_MISMATCH'))

        described_class.new(notification: notification).perform
        expect(NotificationSubscription.exists?(subscription.id)).to be(true)
        expect(Rails.logger).to have_received(:warn).with(/SENDER_ID_MISMATCH/)
      end

      it 'keeps the subscription on other FCM errors' do
        allow(fcm_double).to receive(:send_v1).and_return(fcm_error(503, 'UNAVAILABLE', 'UNAVAILABLE'))

        described_class.new(notification: notification).perform
        expect(NotificationSubscription.exists?(subscription.id)).to be(true)
      end
    end
  end

  context 'when the push server returns error' do
    it 'sends webpush notifications for webpush subscription' do
      with_modified_env VAPID_PUBLIC_KEY: 'test' do
        mock_response = instance_double(Net::HTTPResponse, body: 'Subscription is invalid')
        mock_host = 'fcm.googleapis.com'

        allow(WebPush).to receive(:payload_send).and_raise(WebPush::InvalidSubscription.new(mock_response, mock_host))
        allow(Rails.logger).to receive(:info)

        create(:notification_subscription, :browser_push, user: notification.user)

        expect(Rails.logger).to receive(:info) do |message|
          expect(message).to include('WebPush subscription expired:')
        end

        described_class.new(notification: notification).perform
      end
    end
  end
end
