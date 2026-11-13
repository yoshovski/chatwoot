require 'rails_helper'

RSpec.describe 'Accounts API', type: :request do
  # Public signup needs a captcha (T11); these examples are about other rules.
  before { allow(ChatwootCaptcha).to receive(:configured?).and_return(true) }

  describe 'POST /api/v1/accounts' do
    let(:email) { Faker::Internet.email }
    let(:user_full_name) { Faker::Name.name_with_middle }

    context 'when posting to accounts with correct parameters' do
      let(:account_builder) { double }
      let(:account) { create(:account) }
      let(:user) { create(:user, email: email, account: account, name: user_full_name) }

      before do
        allow(AccountBuilder).to receive(:new).and_return(account_builder)
      end

      it 'calls account builder' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          allow(account_builder).to receive(:perform).and_return([user, account])

          params = { terms_accepted: true, account_name: 'test', email: email, user: nil, locale: nil, user_full_name: user_full_name,
                     password: 'Password1!' }

          post api_v1_accounts_url,
               params: params,
               as: :json

          builder_args = params.except(:password, :terms_accepted).merge(user_password: params[:password], signup: true)
          expect(AccountBuilder).to have_received(:new).with(builder_args.merge(signup_details: { ip: '127.0.0.1', signup_method: 'email' }))
          expect(account_builder).to have_received(:perform)
          expect(response.headers.keys).not_to include('access-token', 'token-type', 'client', 'expiry', 'uid')
          expect(response.parsed_body['email']).to eq(email)
        end
      end

      it 'calls ChatwootCaptcha' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          captcha = double
          allow(account_builder).to receive(:perform).and_return([user, account])
          allow(ChatwootCaptcha).to receive(:new).and_return(captcha)
          allow(captcha).to receive(:valid?).and_return(true)

          params = { terms_accepted: true, account_name: 'test', email: email, user: nil, locale: nil, user_full_name: user_full_name,
                     password: 'Password1!', captcha_response: '123' }

          post api_v1_accounts_url,
               params: params,
               as: :json

          expect(ChatwootCaptcha).to have_received(:new).with('123', remote_ip: '127.0.0.1')
          expect(response.headers.keys).not_to include('access-token', 'token-type', 'client', 'expiry', 'uid')
          expect(response.parsed_body['email']).to eq(email)
        end
      end

      it 'renders error response on invalid params' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          allow(account_builder).to receive(:perform).and_return(nil)

          params = { account_name: nil, email: nil, user: nil, locale: 'en', user_full_name: nil }

          post api_v1_accounts_url,
               params: params,
               as: :json

          expect(AccountBuilder).not_to have_received(:new)
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to eq({ message: I18n.t('errors.signup.invalid_params') }.to_json)
        end
      end
    end

    context 'when the terms are not accepted' do
      it 'refuses the signup' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          allow(AccountBuilder).to receive(:new)
          post api_v1_accounts_url,
               params: { account_name: 'test', email: email, user_full_name: user_full_name, password: 'Password1!', terms_accepted: 'yes' },
               as: :json

          expect(AccountBuilder).not_to have_received(:new)
          expect(response.parsed_body['message']).to eq(I18n.t('errors.signup.terms_not_accepted'))
        end
      end
    end

    context 'when the sign-up form sends a website' do
      it 'stores it on the new account' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          post api_v1_accounts_url,
               params: { terms_accepted: true, account_name: 'test', email: 'owner@shop-example.com', user_full_name: 'Owner',
                         password: 'Password1!', website: ' shop-example.com ' },
               as: :json

          expect(response).to have_http_status(:success)
          expect(User.from_email('owner@shop-example.com').accounts.first.custom_attributes['website']).to eq('shop-example.com')
        end
      end
    end

    context 'when the email cannot sign up' do
      it 'says the email is taken, with a code for the form' do
        create(:user, email: 'taken@shop-example.com')
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          post api_v1_accounts_url,
               params: { terms_accepted: true, account_name: 'test', email: 'taken@shop-example.com', user_full_name: 'Owner',
                         password: 'Password1!' },
               as: :json

          expect(response.parsed_body['code']).to eq('email_taken')
        end
      end

      it 'says the domain is blocked, with a code for the form' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          allow(GlobalConfigService).to receive(:load).and_call_original
          allow(GlobalConfigService).to receive(:load).with('BLOCKED_EMAIL_DOMAINS', '').and_return('blocked-example.com')
          post api_v1_accounts_url,
               params: { terms_accepted: true, account_name: 'test', email: 'owner@blocked-example.com', user_full_name: 'Owner',
                         password: 'Password1!' },
               as: :json

          expect(response.parsed_body).to include('code' => 'email_blocked', 'message' => I18n.t('errors.signup.blocked_domain'))
        end
      end
    end

    context 'when an authenticated user creates a second account' do
      let(:existing_user) { create(:user, password: 'Password1!') }

      it 'returns the full response with account_id' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          post api_v1_accounts_url,
               params: { account_name: 'Second Account', email: existing_user.email,
                         user_full_name: existing_user.name, password: 'Password1!' },
               headers: existing_user.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:success)
          expect(response.parsed_body.dig('data', 'account_id')).to be_present
        end
      end
    end

    context 'when ENABLE_ACCOUNT_SIGNUP env variable is set to false' do
      it 'responds 404 on requests' do
        params = { account_name: 'test', email: email, user_full_name: user_full_name }
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'false' do
          post api_v1_accounts_url,
               params: params,
               as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when ENABLE_ACCOUNT_SIGNUP is stored as boolean false' do
      before do
        GlobalConfig.clear_cache
        InstallationConfig.where(name: 'ENABLE_ACCOUNT_SIGNUP').delete_all
        InstallationConfig.create!(name: 'ENABLE_ACCOUNT_SIGNUP', value: false, locked: false)
      end

      after do
        InstallationConfig.where(name: 'ENABLE_ACCOUNT_SIGNUP').delete_all
        GlobalConfig.clear_cache
      end

      it 'responds 404 on requests' do
        params = { account_name: 'test', email: email, user_full_name: user_full_name, password: 'Password1!' }

        post api_v1_accounts_url,
             params: params,
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when ENABLE_ACCOUNT_SIGNUP env variable is set to api_only' do
      before do
        GlobalConfig.clear_cache
        InstallationConfig.where(name: 'ENABLE_ACCOUNT_SIGNUP').delete_all
      end

      after do
        InstallationConfig.where(name: 'ENABLE_ACCOUNT_SIGNUP').delete_all
        GlobalConfig.clear_cache
      end

      it 'returns auth headers and full response for api_only signup' do
        params = { terms_accepted: true, account_name: 'test', email: email, user_full_name: user_full_name, password: 'Password1!' }
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'api_only' do
          post api_v1_accounts_url,
               params: params,
               as: :json

          expect(response).to have_http_status(:success)
          expect(response.headers.keys).to include('access-token', 'token-type', 'client', 'expiry', 'uid')
        end
      end
    end

    context 'when CW_API_ONLY_SERVER is true' do
      it 'returns auth headers and full response' do
        params = { terms_accepted: true, account_name: 'test', email: email, user_full_name: user_full_name, password: 'Password1!' }
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true', CW_API_ONLY_SERVER: 'true' do
          post api_v1_accounts_url,
               params: params,
               as: :json

          expect(response).to have_http_status(:success)
          expect(response.headers.keys).to include('access-token', 'token-type', 'client', 'expiry', 'uid')
        end
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}' do
    let(:account) { create(:account) }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:user_without_access) { create(:user) }
    let(:admin) { create(:user, account: account, role: :administrator) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an unauthorized user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}",
            headers: user_without_access.create_new_auth_token

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when it is an authenticated user' do
      it 'shows an account' do
        account.update(name: 'new name')

        get "/api/v1/accounts/#{account.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response).to conform_schema(200)
        expect(response.body).to include(account.name)
        expect(response.body).to include(account.locale)
        expect(response.body).to include(account.domain)
        expect(response.body).to include(account.support_email)
        expect(response.body).to include(account.locale)
      end

      it 'exposes the latest chatwoot version' do
        Redis::Alfred.set(Redis::Alfred::LATEST_CHATWOOT_VERSION, '4.16.1')

        get "/api/v1/accounts/#{account.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response.parsed_body['latest_chatwoot_version']).to eq('4.16.1')
      end
    end

    context 'when API and webhook access is disabled for the account' do
      it 'returns forbidden for API token authentication' do
        account_scope = double
        allow(account_scope).to receive(:find).with(account.id.to_s).and_return(account)
        allow_any_instance_of(User).to receive(:accounts).and_return(account_scope) # rubocop:disable RSpec/AnyInstance
        allow(account).to receive(:api_and_webhooks_enabled?).and_return(false)

        get "/api/v1/accounts/#{account.id}",
            headers: { api_access_token: admin.access_token.token },
            as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('API access is not enabled for this account')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/cache_keys' do
    let(:account) { create(:account) }
    let(:admin) { create(:user, account: account, role: :administrator) }

    it 'returns cache_keys as expected' do
      account.update(auto_resolve_duration: 30)

      get "/api/v1/accounts/#{account.id}/cache_keys",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['cache_keys'].keys).to match_array(%w[label inbox team canned_response])
    end

    it 'sets the appropriate cache headers' do
      get "/api/v1/accounts/#{account.id}/cache_keys",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response.headers['Cache-Control']).to include('max-age=10')
      expect(response.headers['Cache-Control']).to include('private')
      expect(response.headers['Cache-Control']).to include('stale-while-revalidate=300')
    end

    context 'when API and webhook access is disabled for the account' do
      it 'returns forbidden for API token authentication' do
        account_scope = double
        allow(account_scope).to receive(:find).with(account.id.to_s).and_return(account)
        allow_any_instance_of(User).to receive(:accounts).and_return(account_scope) # rubocop:disable RSpec/AnyInstance
        allow(account).to receive(:api_and_webhooks_enabled?).and_return(false)

        get "/api/v1/accounts/#{account.id}/cache_keys",
            headers: { api_access_token: admin.access_token.token },
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}' do
    let(:account) { create(:account) }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:admin) { create(:user, account: account, role: :administrator) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an unauthorized user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}",
              headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      params = {
        name: 'New Name',
        locale: 'en',
        domain: 'example.com',
        support_email: 'care@example.com',
        auto_resolve_after: 40,
        auto_resolve_message: 'Auto resolved',
        auto_resolve_ignore_waiting: false,
        timezone: 'Asia/Kolkata',
        industry: 'Technology',
        company_size: '1-10'
      }

      it 'returns a valid schema' do
        patch "/api/v1/accounts/#{account.id}",
              params: params,
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to conform_schema(200)
      end

      it 'modifies an account' do
        patch "/api/v1/accounts/#{account.id}",
              params: params,
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(account.reload.name).to eq(params[:name])
        expect(account.reload.locale).to eq(params[:locale])
        expect(account.reload.domain).to eq(params[:domain])
        expect(account.reload.support_email).to eq(params[:support_email])

        %w[auto_resolve_after auto_resolve_message auto_resolve_ignore_waiting].each do |attribute|
          expect(account.reload.settings[attribute]).to eq(params[attribute.to_sym])
        end

        %w[timezone industry company_size].each do |attribute|
          expect(account.reload.custom_attributes[attribute]).to eq(params[attribute.to_sym])
        end
      end

      it 'updates onboarding step to invite_team if onboarding step is present in account custom attributes' do
        account.update(custom_attributes: { onboarding_step: 'account_update' })
        patch "/api/v1/accounts/#{account.id}",
              params: params,
              headers: admin.create_new_auth_token,
              as: :json

        expect(account.reload.custom_attributes['onboarding_step']).to eq('invite_team')
      end

      it 'will not update onboarding step if onboarding step is not present in account custom attributes' do
        patch "/api/v1/accounts/#{account.id}",
              params: params,
              headers: admin.create_new_auth_token,
              as: :json

        expect(account.reload.custom_attributes['onboarding_step']).to be_nil
      end

      it 'Throws error 422' do
        params[:name] = 'test' * 999

        patch "/api/v1/accounts/#{account.id}",
              params: params,
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['message']).to eq('Name is too long (maximum is 255 characters)')
      end
    end

    context 'when API and webhook access is disabled for the account' do
      it 'returns forbidden without modifying the account for API token authentication' do
        account_scope = double
        allow(account_scope).to receive(:find).with(account.id.to_s).and_return(account)
        allow_any_instance_of(User).to receive(:accounts).and_return(account_scope) # rubocop:disable RSpec/AnyInstance
        allow(account).to receive(:api_and_webhooks_enabled?).and_return(false)

        expect do
          patch "/api/v1/accounts/#{account.id}",
                params: { name: 'Updated through API' },
                headers: { api_access_token: admin.access_token.token },
                as: :json
        end.not_to(change { account.reload.name })

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/update_active_at' do
    let(:account) { create(:account) }
    let(:agent) { create(:user, account: account, role: :agent) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/update_active_at"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'modifies an account' do
        expect(agent.account_users.first.active_at).to be_nil
        post "/api/v1/accounts/#{account.id}/update_active_at",
             params: {},
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(agent.account_users.first.active_at).not_to be_nil
      end
    end

    context 'when API and webhook access is disabled for the account' do
      it 'returns forbidden without updating active_at for API token authentication' do
        account_scope = double
        allow(account_scope).to receive(:find).with(account.id.to_s).and_return(account)
        allow_any_instance_of(User).to receive(:accounts).and_return(account_scope) # rubocop:disable RSpec/AnyInstance
        allow(account).to receive(:api_and_webhooks_enabled?).and_return(false)
        account_user = agent.account_users.first

        post "/api/v1/accounts/#{account.id}/update_active_at",
             headers: { api_access_token: agent.access_token.token },
             as: :json

        expect(response).to have_http_status(:forbidden)
        expect(account_user.reload.active_at).to be_nil
      end
    end
  end
end
