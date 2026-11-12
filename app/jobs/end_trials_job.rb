# Moves accounts whose trial ended without a paid subscription to their plan's after-trial plan (Free). A trial that
# Stripe runs is left alone while its subscription is alive: the webhook decides what happens to it.
class EndTrialsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ended_trials.find_each do |subscription|
      subscription.update!(billing_plan: subscription.billing_plan.after_trial_plan, trial_enabled: false, payment_status: 'active',
                           reset_usage: true)
    end
  end

  private

  def ended_trials
    AccountSubscription.joins(:billing_plan).includes(:account, billing_plan: :after_trial_plan)
                       .where(trial_enabled: true, trial_ends_at: ..Time.current)
                       .where.not(billing_plans: { after_trial_plan_id: nil })
                       .where("(account_subscriptions.payment_status = 'trialing' AND account_subscriptions.stripe_subscription_id IS NULL) " \
                              "OR account_subscriptions.payment_status IN ('canceled', 'incomplete_expired')")
  end
end
