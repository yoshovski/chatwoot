# Sends the billing emails that are due (T08). Daily for every account with billing on; for one account right after
# something changed its billing state (a Stripe webhook, a top-up, AI usage), so those emails do not wait a day.
class Billing::NotificationsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(account_id = nil)
    return deliver(AccountSubscription.find_by(account_id: account_id)) if account_id

    AccountSubscription.where(enabled: true).includes(:account, :billing_plan).find_each do |subscription|
      deliver(subscription)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: subscription.account).capture_exception
    end
  end

  private

  def deliver(subscription)
    Billing::NotificationsService.new(subscription).deliver_due if subscription
  end
end
