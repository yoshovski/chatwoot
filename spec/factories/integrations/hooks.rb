FactoryBot.define do
  factory :integrations_hook, class: 'Integrations::Hook' do
    app_id { 'slack' }
    account
    settings { { test: 'test' } }
    status { Integrations::Hook.statuses['enabled'] }
    access_token { SecureRandom.hex }
    reference_id { SecureRandom.hex }

    trait :dialogflow do
      app_id { 'dialogflow' }
      settings { { project_id: 'test', credentials: {}, region: 'global', language_code: 'en-US' } }
    end

    trait :dyte do
      app_id { 'dyte' }
      settings { { account_id: 'account_id', app_id: 'app_id', api_token: 'api_token' } }
    end

    trait :google_translate do
      app_id { 'google_translate' }
      settings { { project_id: 'test', credentials: {} } }
    end

    trait :openai do
      app_id { 'openai' }
      settings { { api_key: 'api_key' } }
    end

    trait :linear do
      app_id { 'linear' }
      access_token { SecureRandom.hex }
    end

    trait :shopify do
      app_id { 'shopify' }
      access_token { SecureRandom.hex }
      reference_id { 'test-store.myshopify.com' }
    end

    trait :hubspot do
      app_id { 'hubspot' }
      access_token { 'hubspot-access-token' }
      settings do
        {
          'field_mapping' => { 'email' => 'email', 'firstname' => 'firstname', 'lastname' => 'lastname', 'phone' => 'phone' },
          'sync_contacts' => true,
          'save_transcripts' => true,
          'refresh_token' => 'na1-refresh-token',
          'expires_on' => 1.hour.from_now.utc.iso8601,
          'portal_id' => 12_345,
          'hub_domain' => 'example-portal.hubspot.com',
          'user' => 'admin@example.com',
          'scopes' => %w[oauth crm.objects.contacts.read crm.objects.contacts.write crm.schemas.contacts.read]
        }
      end
    end

    trait :leadsquared do
      app_id { 'leadsquared' }
      settings do
        {
          'access_key' => SecureRandom.hex,
          'secret_key' => SecureRandom.hex,
          'endpoint_url' => 'https://api.leadsquared.com/'
        }
      end
    end
  end
end
