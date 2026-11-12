# Computes the Super Admin billing overview once a day (and on demand from the page), so the page never computes or
# calls Stripe on load.
class Enterprise::Billing::OverviewSnapshotJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Enterprise::Billing::OverviewService.store!
  end
end
