class Api::V1::Accounts::SubscriptionCancellationsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :validate_decision, only: %i[create accept confirm dismiss]
  rescue_from Enterprise::Billing::AccountCheckoutService::Unavailable, with: :unavailable
  rescue_from Stripe::StripeError, with: :stripe_failed

  def create
    render json: service.start(reason: params.fetch(:reason, 'other'), feature: params[:feature])
  end

  def accept
    return head :unprocessable_entity if params[:reason] == 'unused' && [1, 2, 3].exclude?(params[:months])

    if params[:reason] == 'feature'
      return head :unprocessable_entity unless params[:plan_id].is_a?(Integer)

      plan = BillingPlan.find_by(id: params[:plan_id])
    end
    render json: service.decide(**decision, action: 'accept', months: params[:months], plan: plan)
  end

  def confirm
    render json: service.decide(**decision, action: 'confirm')
  end

  def dismiss
    render json: service.dismiss(**decision)
  end

  def keep
    render json: service.keep
  end

  def resume
    render json: service.resume
  end

  private

  def decision
    { id: params[:id], reason: params.fetch(:reason, 'other'), feature: params[:feature] }
  end

  def service
    Enterprise::Billing::CancellationService.new(account: Current.account, actor: Current.user)
  end

  def validate_decision
    reason = params.fetch(:reason, 'other')
    valid = reason.is_a?(String) && AccountCancellation::REASONS.include?(reason) &&
            (params[:feature].nil? || (params[:feature].is_a?(String) && params[:feature].length <= 2000))
    head :unprocessable_entity unless valid
  end

  def unavailable
    render json: { error: I18n.t('errors.account_subscription.unavailable') }, status: :unprocessable_entity
  end

  def stripe_failed
    render json: { error: I18n.t('errors.account_subscription.payment_failed') }, status: :bad_gateway
  end
end
