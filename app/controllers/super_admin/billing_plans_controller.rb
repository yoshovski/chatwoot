class SuperAdmin::BillingPlansController < SuperAdmin::ApplicationController
  def scoped_resource
    BillingPlan.ordered
  end

  def create_stripe_prices
    return head :not_found unless ChatwootApp.enterprise?

    Enterprise::Billing::PlanStripePricesService.new(plan: requested_resource).perform
    redirect_to [namespace, requested_resource], notice: I18n.t('super_admin.billing_plan.stripe_prices_created')
  rescue Stripe::StripeError => e
    redirect_to [namespace, requested_resource], alert: I18n.t('super_admin.billing_plan.stripe_prices_failed', error: e.message)
  end

  def resource_params
    permitted = super
    plan_params = params.require(:billing_plan)
    permitted[:feature_settings] = plan_params.fetch(:feature_settings, {}).permit(*BillingPlan::FEATURES).to_h
    permitted[:add_on_prices] = plan_params.fetch(:add_on_prices, {}).permit(*BillingPlan::FEATURES).to_h
    permitted
  end
end
