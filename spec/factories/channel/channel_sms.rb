FactoryBot.define do
  factory :channel_sms, class: 'Channel::Sms' do
    sequence(:phone_number) { |n| "+123456789#{n}1" }
    account
    provider_config do
      { 'account_id' => '1',
        'application_id' => '1',
        'api_key' => '1',
        'api_secret' => '1' }
    end

    trait :telnyx do
      provider { 'telnyx' }
      provider_config do
        { 'api_key' => 'KEYtest', 'messaging_profile_id' => 'mp-1' }
      end
    end

    # Pre-provisioned so creating it makes no Telnyx API calls.
    trait :telnyx_voice do
      provider { 'telnyx' }
      provider_config do
        { 'api_key' => 'KEYtest', 'messaging_profile_id' => 'mp-1', 'voice_enabled' => true,
          'account_sid' => 'acct-uuid', 'texml_application_id' => 'texml-1', 'credential_connection_id' => 'cc-1' }
      end
    end

    after(:create) do |channel_sms|
      create(:inbox, channel: channel_sms, account: channel_sms.account)
    end
  end
end
