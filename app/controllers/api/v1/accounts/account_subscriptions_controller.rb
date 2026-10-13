class Api::V1::Accounts::AccountSubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: :show

  def show
    subscription = Current.account.subscription_settings
    return render json: subscription.usage_summary unless Current.account_user.administrator?

    sync_failed = refresh_subscription
    subscription.reload if subscription.persisted?
    render json: subscription.summary.merge(billing_sync_failed: sync_failed,
                                            can_checkout: !sync_failed && subscription.pricing_summary[:can_checkout])
  end

  def checkout
    return head :not_found unless ChatwootApp.enterprise?
    return head :unprocessable_entity unless %w[month year].include?(params[:interval])

    render json: Enterprise::Billing::AccountCheckoutService.new(account: Current.account).checkout(interval: params[:interval])
  rescue Enterprise::Billing::AccountCheckoutService::Unavailable
    render json: { error: I18n.t('errors.account_subscription.unavailable') }, status: :unprocessable_entity
  rescue Stripe::StripeError
    render json: { error: I18n.t('errors.account_subscription.payment_failed') }, status: :bad_gateway
  end

  def change_interval
    return head :not_found unless ChatwootApp.enterprise?
    return head :unprocessable_entity unless %w[month year].include?(params[:interval])

    render json: Enterprise::Billing::AccountIntervalChangeService.new(account: Current.account).perform(interval: params[:interval])
  rescue Enterprise::Billing::AccountCheckoutService::Unavailable
    render json: { error: I18n.t('errors.account_subscription.unavailable') }, status: :unprocessable_entity
  rescue Stripe::StripeError
    render json: { error: I18n.t('errors.account_subscription.payment_failed') }, status: :bad_gateway
  end

  def payment
    return head :not_found unless ChatwootApp.enterprise?

    render json: Enterprise::Billing::AccountCheckoutService.new(account: Current.account).payment
  rescue Enterprise::Billing::AccountCheckoutService::Unavailable
    render json: { error: I18n.t('errors.account_subscription.unavailable') }, status: :unprocessable_entity
  rescue Stripe::StripeError
    render json: { error: I18n.t('errors.account_subscription.payment_failed') }, status: :bad_gateway
  end

  def portal
    return head :not_found unless ChatwootApp.enterprise?

    render json: Enterprise::Billing::AccountCheckoutService.new(account: Current.account).portal
  rescue Enterprise::Billing::AccountCheckoutService::Unavailable
    render json: { error: I18n.t('errors.account_subscription.unavailable') }, status: :unprocessable_entity
  rescue Stripe::StripeError
    render json: { error: I18n.t('errors.account_subscription.payment_failed') }, status: :bad_gateway
  end

  private

  def refresh_subscription
    return false unless ChatwootApp.enterprise? && params[:sync] == 'true'

    Enterprise::Billing::AccountSubscriptionSyncService.refresh(Current.account)
    false
  rescue Stripe::StripeError
    true
  end
end
