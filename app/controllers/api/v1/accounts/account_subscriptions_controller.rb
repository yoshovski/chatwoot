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

  # plan_id picks a plan; without it, Checkout sells the price Super Admin saved on the account.
  def checkout
    return head :not_found unless ChatwootApp.enterprise?
    return head :unprocessable_entity unless %w[month year].include?(params[:interval])

    plan = BillingPlan.find_by(id: params[:plan_id]) if params.key?(:plan_id)
    return head :unprocessable_entity if params.key?(:plan_id) && plan.nil?

    render json: Enterprise::Billing::AccountCheckoutService.new(account: Current.account).checkout(interval: params[:interval], plan: plan)
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

  def change_plan
    return head :not_found unless ChatwootApp.enterprise?
    return head :unprocessable_entity unless %w[month year].include?(params[:interval])

    plan = BillingPlan.find_by(id: params[:plan_id])
    return head :unprocessable_entity unless plan

    render json: Enterprise::Billing::AccountPlanChangeService.new(account: Current.account).perform(plan: plan, interval: params[:interval])
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

  def invoices
    return head :not_found unless ChatwootApp.enterprise?

    render json: { invoices: Enterprise::Billing::InvoiceListService.new(account: Current.account).perform }
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

  def top_up
    return head :not_found unless ChatwootApp.enterprise?

    render json: Enterprise::Billing::TopUpService.new(account: Current.account).buy(request_id: params[:request_id])
  rescue Enterprise::Billing::TopUpService::Unavailable
    render json: { error: I18n.t('errors.account_subscription.unavailable') }, status: :unprocessable_entity
  rescue Enterprise::Billing::TopUpService::PaymentFailed
    render json: { error: I18n.t('errors.account_subscription.card_declined') }, status: :unprocessable_entity
  rescue Stripe::StripeError
    render json: { error: I18n.t('errors.account_subscription.payment_failed') }, status: :bad_gateway
  end

  # Turning auto top-up on also clears the note that a failed payment switched it off.
  def top_up_settings
    subscription = Current.account.account_subscription
    return head :unprocessable_entity unless subscription&.top_up_available?

    attributes = params.permit(:auto_top_up_enabled, :auto_top_up_max_packs).to_h
    attributes[:auto_top_up_failed_at] = nil if ActiveModel::Type::Boolean.new.cast(attributes['auto_top_up_enabled'])
    return render json: { error: subscription.errors.full_messages.to_sentence }, status: :unprocessable_entity unless subscription.update(attributes)

    subscription.request_auto_top_up
    render json: subscription.top_up_summary
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
