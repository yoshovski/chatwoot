# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountBuilder do
  let(:email) { 'user@example.com' }
  let(:user_password) { 'Password123!' }
  let(:account_name) { 'Test Account' }
  let(:user_full_name) { 'Test User' }
  let(:validation_service) { instance_double(Account::SignUpEmailValidationService, perform: true) }
  let(:account_builder) do
    described_class.new(
      account_name: account_name,
      email: email,
      user_full_name: user_full_name,
      user_password: user_password,
      confirmed: true
    )
  end

  # Installation configs are cached in Redis, which the example's rollback does not clear.
  after { GlobalConfig.clear_cache }

  # Mock the email validation service
  before do
    allow(Account::SignUpEmailValidationService).to receive(:new).with(email).and_return(validation_service)
  end

  describe 'the signup trial' do
    let(:signup_builder) do
      described_class.new(account_name: account_name, email: email, user_full_name: user_full_name, user_password: user_password, signup: true)
    end
    let!(:free) { create(:billing_plan, name: 'Free', ai_conversations_limit: 0, conversations_limit: 100) }
    let!(:growth) do
      create(:billing_plan, name: 'Growth', ai_conversations_limit: 150, trial_ai_conversations_limit: 50, trial_days: 14,
                            signup_default: true, after_trial_plan: free, features: %w[captain_integration])
    end

    it 'puts a public signup on the signup plan for a capped 14 day trial' do
      _user, account = signup_builder.perform

      subscription = account.reload.account_subscription
      expect(subscription).to have_attributes(billing_plan: growth, trial_enabled: true, payment_status: 'trialing', enabled: true)
      expect(subscription.trial_ends_at).to be_within(1.minute).of(14.days.from_now)
      expect(subscription.effective_limit).to eq(50)
      expect(account.feature_enabled?('captain_integration')).to be(true)
    end

    it 'records the consent, the IP and the trial on the signup' do
      create(:installation_config, name: 'TERMS_VERSION', value: '2026-11-13')
      create(:installation_config, name: 'PRIVACY_VERSION', value: '2026-11-01')
      user, account = described_class.new(account_name: account_name, user_full_name: user_full_name, email: email, user_password: user_password,
                                          signup: true, signup_details: { ip: '203.0.113.7', signup_method: 'email' }).perform

      expect(account.account_signup).to have_attributes(
        user: user, email: email, email_domain: 'example.com', ip: '203.0.113.7', signup_method: 'email', trial_granted: true,
        terms_version: '2026-11-13', privacy_version: '2026-11-01'
      )
      expect(account.account_signup.consented_at).to be_within(1.minute).of(Time.current)
    end

    it 'lets the AI reply only after the email is confirmed' do
      user, account = signup_builder.perform

      expect(account.reload.account_subscription.ai_pause_reason).to eq('email_unconfirmed')

      user.confirm
      expect(account.reload.account_subscription.ai_reply_allowed?).to be(true)
    end

    it 'starts a second signup from a business domain that had a trial on the plan after the trial' do
      signup_builder.perform
      other_email = 'second@example.com'
      allow(Account::SignUpEmailValidationService).to receive(:new).with(other_email).and_return(validation_service)

      _user, account = described_class.new(account_name: account_name, user_full_name: user_full_name, email: other_email,
                                           user_password: user_password, signup: true).perform

      expect(account.account_subscription).to have_attributes(billing_plan: free, trial_enabled: false, payment_status: 'active')
      expect(account.account_signup).to have_attributes(trial_granted: false, trial_refused_reason: 'domain_used')
    end

    it 'gives a trial to each free-mail signup' do
      %w[anna@gmail.com bruno@gmail.com].each do |address|
        allow(Account::SignUpEmailValidationService).to receive(:new).with(address).and_return(validation_service)
        _user, account = described_class.new(account_name: account_name, user_full_name: user_full_name, email: address, user_password: user_password,
                                             signup: true).perform

        expect(account.account_subscription.billing_plan).to eq(growth)
      end
    end

    it 'gives no plan to an account that is not a public signup' do
      _user, account = account_builder.perform

      expect(account.reload.account_subscription).to be_nil
    end

    it 'gives no plan when no plan is the signup default' do
      growth.update!(signup_default: false)
      _user, account = signup_builder.perform

      expect(account.reload.account_subscription).to be_nil
    end
  end

  describe '#perform' do
    context 'when valid params are passed' do
      it 'creates a new account with correct name' do
        _user, account = account_builder.perform
        expect(account).to be_an(Account)
        expect(account.name).to eq(account_name)
      end

      it 'creates a new confirmed user with correct details' do
        user, _account = account_builder.perform
        expect(user).to be_a(User)
        expect(user.email).to eq(email)
        expect(user.name).to eq(user_full_name)
        expect(user.confirmed?).to be(true)
      end

      it 'links user to account as administrator' do
        user, account = account_builder.perform
        expect(user.account_users.first.role).to eq('administrator')
        expect(user.accounts.first).to eq(account)
      end

      it 'increments the counts of models' do
        expect do
          account_builder.perform
        end.to change(Account, :count).by(1)
           .and change(User, :count).by(1)
           .and change(AccountUser, :count).by(1)
      end

      it 'initializes the onboarding step to account_details' do
        _user, account = account_builder.perform
        expect(account.custom_attributes['onboarding_step']).to eq('account_details')
      end
    end
  end
end
