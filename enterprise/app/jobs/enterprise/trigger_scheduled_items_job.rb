module Enterprise::TriggerScheduledItemsJob
  def perform
    super

    ## Triggers Enterprise specific jobs
    ####################################

    # Triggers Account Sla jobs
    Sla::TriggerSlasForAccountsJob.perform_later

    # Marks knowledge Ready that Dify finished after polling gave up
    Captain::Dify::RecheckTimedOutDocumentsJob.perform_later
  end
end
