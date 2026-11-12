# The opt-out link in the usage emails (T08). The signed token names one account user, so it works without a login;
# the POST is also the one-click unsubscribe that mail clients send (List-Unsubscribe-Post).
class BillingUsageEmailsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  skip_forgery_protection
  layout false
  before_action :set_account_user

  def show; end

  def update
    @account_user.update!(billing_usage_emails: params[:enabled] == 'true')
    render :show
  end

  private

  def set_account_user
    @account_user = AccountUser.find_signed(params[:token].to_s, purpose: Billing::NotificationMailer::OPT_OUT_PURPOSE)
    head :not_found unless @account_user
  end
end
