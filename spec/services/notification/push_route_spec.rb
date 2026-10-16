require 'rails_helper'

describe Notification::PushRoute do
  let(:user) { create(:user) }
  let(:own_app) do
    create(:notification_subscription, :fcm, user: user, identifier: 'own',
                                             subscription_attributes: { push_token: 'token', app_id: 'com.chatoctave.app' })
  end
  let(:chatwoot_app) do
    create(:notification_subscription, :fcm, user: user, identifier: 'chatwoot',
                                             subscription_attributes: { push_token: 'token' })
  end
  let(:other_app) do
    create(:notification_subscription, :fcm, user: user, identifier: 'other',
                                             subscription_attributes: { push_token: 'token', app_id: 'com.example.app' })
  end

  context 'with Firebase credentials' do
    before do
      allow(GlobalConfigService).to receive(:load).with('FIREBASE_PROJECT_ID', nil).and_return('test-project')
      allow(GlobalConfigService).to receive(:load).with('FIREBASE_CREDENTIALS', nil).and_return('{}')
    end

    it 'sends our own app through our Firebase project' do
      expect(described_class.for(own_app)).to eq(:own_firebase)
    end

    it 'sends the official Chatwoot app through the relay' do
      expect(described_class.for(chatwoot_app)).to eq(:chatwoot_relay)
    end

    it 'sends apps that are not ours through the relay' do
      expect(described_class.for(other_app)).to eq(:chatwoot_relay)
    end

    it 'skips apps that are not ours when the relay is disabled' do
      with_modified_env ENABLE_PUSH_RELAY_SERVER: 'false' do
        expect(described_class.for(chatwoot_app)).to eq(:none)
      end
    end

    it 'reads the own app list from OWN_MOBILE_APP_IDS' do
      with_modified_env OWN_MOBILE_APP_IDS: 'com.example.app, com.chatoctave.app' do
        expect(described_class.for(other_app)).to eq(:own_firebase)
      end
    end
  end

  context 'without Firebase credentials' do
    before do
      allow(GlobalConfigService).to receive(:load).with('FIREBASE_PROJECT_ID', nil).and_return(nil)
      allow(GlobalConfigService).to receive(:load).with('FIREBASE_CREDENTIALS', nil).and_return(nil)
    end

    it 'skips our own app with a warning, because the relay cannot reach it' do
      allow(Rails.logger).to receive(:warn)

      expect(described_class.for(own_app)).to eq(:none)
      expect(Rails.logger).to have_received(:warn).with(/Push subscription #{own_app.id} .* skipped/)
    end

    it 'sends the official Chatwoot app through the relay' do
      expect(described_class.for(chatwoot_app)).to eq(:chatwoot_relay)
    end
  end

  it 'has no mobile route for browser push' do
    expect(described_class.for(create(:notification_subscription, user: user))).to eq(:none)
  end
end
