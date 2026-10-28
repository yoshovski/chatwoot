require 'administrate/base_dashboard'

class BillingPlanDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    description: Field::Text,
    active: Field::Boolean,
    position: Field::Number,
    currency: Field::Select.with_options(collection: AccountSubscription::SUPPORTED_CURRENCIES),
    monthly_price: Field::String,
    ai_conversations_limit: Field::Number,
    trial_ai_conversations_limit: Field::Number,
    trial_days: Field::Number,
    agents_limit: Field::Number,
    inboxes_limit: Field::Number,
    documents_limit: Field::Number,
    features: BillingPlanFeaturesField,
    account_subscriptions: CountField,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[name active monthly_price currency account_subscriptions].freeze
  SHOW_PAGE_ATTRIBUTES = %i[name description active position currency monthly_price ai_conversations_limit trial_ai_conversations_limit
                            trial_days agents_limit inboxes_limit documents_limit features account_subscriptions].freeze
  FORM_ATTRIBUTES = %i[name description active position currency monthly_price ai_conversations_limit trial_ai_conversations_limit
                       trial_days agents_limit inboxes_limit documents_limit features].freeze

  def display_resource(plan)
    plan.name
  end

  def permitted_attributes(action = nil)
    super - [:features]
  end
end
