class SuperAdmin::BillingPlansController < SuperAdmin::ApplicationController
  def scoped_resource
    BillingPlan.ordered
  end

  def resource_params
    permitted = super
    plan_params = params.require(:billing_plan)
    permitted[:feature_settings] = plan_params.fetch(:feature_settings, {}).permit(*BillingPlan::FEATURES).to_h
    permitted[:add_on_prices] = plan_params.fetch(:add_on_prices, {}).permit(*BillingPlan::FEATURES).to_h
    permitted
  end
end
