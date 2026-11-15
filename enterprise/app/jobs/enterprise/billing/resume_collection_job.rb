# Stripe resumes collection automatically. Refresh the local AI state even if no one opens Billing that day.
class Enterprise::Billing::ResumeCollectionJob < ApplicationJob
  queue_as :scheduled_jobs
  retry_on Stripe::StripeError, wait: :polynomially_longer, attempts: 10

  def perform(account_id, subscription_id)
    account = Account.find_by(id: account_id)
    return unless account&.account_subscription&.stripe_subscription_id == subscription_id

    Enterprise::Billing::AccountSubscriptionSyncService.refresh(account)
  end
end
