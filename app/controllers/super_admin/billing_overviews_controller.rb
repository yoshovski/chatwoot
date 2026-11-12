# Super Admin billing overview (T10). The page shows the copy Enterprise::Billing::OverviewSnapshotJob keeps in Redis
# and makes no outside call; Refresh queues the job.
class SuperAdmin::BillingOverviewsController < SuperAdmin::ApplicationController
  before_action { head :not_found unless ChatwootApp.enterprise? }

  def show
    @overview = Enterprise::Billing::OverviewService.cached
  end

  def refresh
    Enterprise::Billing::OverviewSnapshotJob.perform_later
    redirect_to super_admin_billing_overview_path, notice: I18n.t('super_admin.billing_overview.refresh_queued')
  end
end
