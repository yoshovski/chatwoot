# The Super Admin plan behind an account subscription: limits it inherits, the capped trial, plan feature flags and
# the per-product usage that Billing and Home show.
module AccountSubscriptionPlan
  extend ActiveSupport::Concern

  included do
    belongs_to :billing_plan, optional: true

    validate :validate_add_ons
    before_validation :initialize_plan
    after_save_commit :sync_plan_features, if: -> { billing_plan && (saved_change_to_billing_plan_id? || saved_change_to_add_ons?) }
  end

  # The account's own value wins; a blank one inherits the plan's.
  def effective_limit
    return billing_plan.trial_ai_conversations_limit if trial_capped?

    monthly_limit.nil? ? billing_plan&.ai_conversations_limit : monthly_limit
  end

  def trial_capped?
    trial_active? && billing_plan&.trial_ai_conversations_limit.present?
  end

  def sync_plan_features
    plan_features = billing_plan.enabled_features_for(self)
    account.enable_features(*plan_features)
    account.disable_features(*(BillingPlan::FEATURES - plan_features))
    account.save!
  end

  # One entry per product on Billing and Home. A nil limit means none is set.
  def product_usage
    limits = account.usage_limits
    {
      ai_conversations: { used: consumed, limit: (effective_limit if enabled?), period: trial_capped? ? 'trial' : 'month' },
      agents: { used: account.account_users.count, limit: finite_limit(limits[:agents]) },
      inboxes: { used: account.inboxes.count, limit: finite_limit(limits[:inboxes]) },
      documents: { used: account.try(:captain_documents)&.count || 0, limit: finite_limit(limits.dig(:captain, :documents, :total_count)) }
    }
  end

  def plan_summary
    billing_plan&.summary(self)
  end

  private

  def finite_limit(limit)
    return if limit.nil? || limit.to_i >= ChatwootApp.max_limit

    limit.to_i
  end

  def validate_add_ons
    errors.add(:add_ons, :invalid) unless add_ons.is_a?(Array) && add_ons.all?(String)
  end

  # Assigning a plan turns billing on for the account.
  def initialize_plan
    self.enabled = true if billing_plan && will_save_change_to_billing_plan_id?
    self.add_ons = add_ons.compact_blank if add_ons.is_a?(Array)
  end

  def plan_trial_days
    billing_plan&.trial_days || trial_days
  end

  def daily_counts(scope, column, start_date)
    scope.where(column => Time.utc(start_date.year, start_date.month, start_date.day)..Time.current)
         .group(Arel.sql("DATE(#{column})")).count
  end
end
