# frozen_string_literal: true

class AccountBuilder
  include CustomExceptions::Account
  # signup: a public signup. signup_details: { ip:, signup_method: } for its AccountSignup row (T11); the caller has
  # checked consent to the terms, so the row records it with the current versions.
  pattr_initialize [:account_name, :email!, :confirmed, :user, :user_full_name, :user_password, :super_admin, :locale, :signup,
                    :signup_details]

  def perform
    if @user.nil?
      validate_email
      validate_user
    end
    ActiveRecord::Base.transaction do
      @account = create_account
      @user = create_and_link_user
      record_signup if @signup
    end
    [@user, @account]
  rescue StandardError => e
    Rails.logger.debug e.inspect
    raise e
  end

  private

  def user_full_name
    # the empty string ensures that not-null constraint is not violated
    @user_full_name || ''
  end

  def account_name
    # the empty string ensures that not-null constraint is not violated
    @account_name || ''
  end

  def validate_email
    Account::SignUpEmailValidationService.new(@email).perform
  end

  def validate_user
    if User.exists?(email: @email)
      raise UserExists.new(email: @email)
    else
      true
    end
  end

  def create_account
    @account = Account.create!(
      name: account_name,
      locale: I18n.locale,
      custom_attributes: { 'onboarding_step' => 'account_details' }
    )
    Current.account = @account
  end

  # Public signups start on the signup plan's trial, one per website domain (Signup::TrialService); EndTrialsJob moves
  # an unpaid one to the plan after it.
  def record_signup
    details = @signup_details || {}
    @account.create_account_signup!(
      user: @user, email: @user.email, email_domain: AccountSignup.business_domain(@user.email), ip: details[:ip],
      signup_method: details[:signup_method] || 'email', consented_at: Time.current,
      terms_version: GlobalConfigService.load('TERMS_VERSION', ''), privacy_version: GlobalConfigService.load('PRIVACY_VERSION', '')
    )
    Signup::TrialService.new(@account).start!
  end

  def create_and_link_user
    if @user.present? || create_user
      link_user_to_account(@user, @account)
      @user
    else
      raise UserErrors.new(errors: @user.errors)
    end
  end

  def link_user_to_account(user, account)
    AccountUser.create!(
      account_id: account.id,
      user_id: user.id,
      role: AccountUser.roles['administrator']
    )
  end

  def create_user
    @user = User.new(email: @email,
                     password: user_password,
                     password_confirmation: user_password,
                     name: user_full_name)
    @user.type = 'SuperAdmin' if @super_admin
    @user.confirm if @confirmed
    @user.save!
  end
end
