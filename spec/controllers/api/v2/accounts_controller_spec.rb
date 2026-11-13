require 'rails_helper'

RSpec.describe 'Accounts API', type: :request do
  # Public signup needs a captcha (T11); these examples are about other rules.
  before { allow(ChatwootCaptcha).to receive(:configured?).and_return(true) }

  describe 'POST /api/v2/accounts' do
    let(:email) { Faker::Internet.email }

    context 'when posting to accounts with correct parameters' do
      let(:account_builder) { double }
      let(:account) { create(:account) }
      let(:user) { create(:user, email: email, account: account) }

      before do
        allow(AccountBuilder).to receive(:new).and_return(account_builder)
      end

      it 'calls account builder' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          allow(account_builder).to receive(:perform).and_return([user, account])

          params = { terms_accepted: true, email: email, user: nil, locale: nil, password: 'Password1!' }

          post api_v2_accounts_url,
               params: params,
               as: :json

          builder_args = params.except(:password, :terms_accepted).merge(user_password: params[:password], signup: true)
          expect(AccountBuilder).to have_received(:new).with(builder_args.merge(signup_details: { ip: '127.0.0.1', signup_method: 'api' }))
          expect(account_builder).to have_received(:perform)
          expect(response.headers.keys).to include('access-token', 'token-type', 'client', 'expiry', 'uid')
          expect(response.body).to include('en')
        end
      end

      it 'updates the onboarding step in custom attributes' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          allow(account_builder).to receive(:perform).and_return([user, account])

          params = { terms_accepted: true, email: email, user: nil, locale: nil, password: 'Password1!' }

          post api_v2_accounts_url,
               params: params,
               as: :json

          expect(account.reload.custom_attributes['onboarding_step']).to eq('profile_update')
        end
      end

      it 'calls ChatwootCaptcha' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          captcha = double
          allow(account_builder).to receive(:perform).and_return([user, account])
          allow(ChatwootCaptcha).to receive(:new).and_return(captcha)
          allow(captcha).to receive(:valid?).and_return(true)

          params = { terms_accepted: true, email: email, user: nil, password: 'Password1!', locale: nil, captcha_response: '123' }

          post api_v2_accounts_url,
               params: params,
               as: :json

          expect(ChatwootCaptcha).to have_received(:new).with('123', remote_ip: '127.0.0.1')
          expect(response.headers.keys).to include('access-token', 'token-type', 'client', 'expiry', 'uid')
          expect(response.body).to include('en')
        end
      end

      it 'renders error response on invalid params' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          allow(account_builder).to receive(:perform).and_return(nil)

          params = { terms_accepted: true, email: nil, user: nil, locale: nil }

          post api_v2_accounts_url,
               params: params,
               as: :json

          builder_args = params.except(:terms_accepted).merge(user_password: params[:password], signup: true)
          expect(AccountBuilder).to have_received(:new).with(builder_args.merge(signup_details: { ip: '127.0.0.1', signup_method: 'api' }))
          expect(account_builder).to have_received(:perform)
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to eq({ message: I18n.t('errors.signup.failed') }.to_json)
        end
      end
    end

    context 'when ENABLE_ACCOUNT_SIGNUP env variable is set to false' do
      it 'responds 404 on requests' do
        params = { email: email }
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'false' do
          post api_v2_accounts_url,
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
        params = { email: email, password: 'Password1!' }

        post api_v2_accounts_url,
             params: params,
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when ENABLE_ACCOUNT_SIGNUP env variable is set to api_only' do
      let(:account_builder) { double }
      let(:account) { create(:account) }
      let(:user) { create(:user, email: email, account: account) }

      it 'does not respond 404 on requests' do
        allow(AccountBuilder).to receive(:new).and_return(account_builder)
        allow(account_builder).to receive(:perform).and_return([user, account])

        params = { terms_accepted: true, email: email, user: nil, password: 'Password1!', locale: nil }
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'api_only' do
          post api_v2_accounts_url,
               params: params,
               as: :json

          builder_args = params.except(:password, :terms_accepted).merge(user_password: params[:password], signup: true)
          expect(AccountBuilder).to have_received(:new).with(builder_args.merge(signup_details: { ip: '127.0.0.1', signup_method: 'api' }))
          expect(response).to have_http_status(:success)
        end
      end
    end
  end
end
