class Api::V2::AccountsController < Api::BaseController
  include AuthHelper

  skip_before_action :authenticate_user!, :set_current_user, :handle_with_exception,
                     only: [:create], raise: false
  before_action :check_signup_enabled, only: [:create]
  before_action :validate_captcha, only: [:create]
  before_action :ensure_terms_accepted, only: [:create]
  before_action :fetch_account, except: [:create]
  before_action :check_authorization, except: [:create]

  rescue_from CustomExceptions::Account::InvalidEmail,
              CustomExceptions::Account::UserExists,
              CustomExceptions::Account::UserErrors,
              CustomExceptions::Account::TermsNotAccepted,
              with: :render_error_response

  def create
    @user, @account = AccountBuilder.new(
      email: account_params[:email],
      user_password: account_params[:password],
      locale: account_params[:locale],
      user: current_user, signup: current_user.nil?, signup_details: signup_details
    ).perform

    fetch_account_and_user_info
    update_account_info if @account.present?

    if @user
      send_auth_headers(@user)
      render 'api/v1/accounts/create', format: :json, locals: { resource: @user }
    else
      render_error_response(CustomExceptions::Account::SignupFailed.new({}))
    end
  end

  private

  def account_attributes
    {
      custom_attributes: @account.custom_attributes.merge({ 'onboarding_step' => 'profile_update' })
    }
  end

  def update_account_info
    @account.update!(
      account_attributes
    )
  end

  def fetch_account_and_user_info; end

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def account_params
    params.permit(:account_name, :email, :name, :password, :locale, :domain, :support_email, :user_full_name)
  end

  def check_signup_enabled
    raise ActionController::RoutingError, 'Not Found' unless GlobalConfigService.account_signup_enabled?
  end

  def validate_captcha
    captcha = ChatwootCaptcha.new(params[:captcha_response], remote_ip: request.remote_ip)
    raise ActionController::InvalidAuthenticityToken, 'Invalid Captcha' unless captcha.valid?
  end

  def signup_details
    { ip: request.remote_ip, signup_method: 'api' }
  end

  # A public signup agrees to the terms and the privacy policy; AccountBuilder stores the versions (T11).
  def ensure_terms_accepted
    return if current_user
    raise CustomExceptions::Account::TermsNotAccepted.new({}) unless params[:terms_accepted] == true
  end
end

Api::V2::AccountsController.prepend_mod_with('Api::V2::AccountsController')
