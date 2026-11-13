# The unsubscribe link in the first-week emails (T15). The signed token names one account user, so it works without a
# login; the POST is also the one-click unsubscribe that mail clients send (List-Unsubscribe-Post).
class OnboardingEmailsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  skip_forgery_protection
  layout false
  before_action :set_account_user
  around_action :switch_locale

  def show; end

  def update
    @account_user.update!(onboarding_emails: params[:enabled] == 'true')
    render :show
  end

  private

  def switch_locale(&)
    locale = @account_user.user.ui_settings&.dig('locale').presence || @account_user.account.locale
    I18n.with_locale(Onboarding::FirstWeekMailer.copy_locale(locale), &)
  end

  def set_account_user
    @account_user = AccountUser.find_signed(params[:token].to_s, purpose: Onboarding::FirstWeekMailer::OPT_OUT_PURPOSE)
    head :not_found unless @account_user
  end
end
