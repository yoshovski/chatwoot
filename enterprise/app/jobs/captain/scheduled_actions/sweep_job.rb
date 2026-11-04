# Every five minutes (from TriggerScheduledItemsJob): dispatches pending actions whose job was lost and prunes finished
# rows after a month.
class Captain::ScheduledActions::SweepJob < ApplicationJob
  queue_as :scheduled_jobs

  LOST_AFTER = 1.minute
  KEEP_FINISHED_FOR = 30.days

  def perform
    Captain::ScheduledAction.pending.where(due_at: ...LOST_AFTER.ago).limit(Limits::BULK_ACTIONS_LIMIT).pluck(:id).each do |id|
      Captain::ScheduledActions::DispatchJob.perform_later(id)
    end
    Captain::ScheduledAction.finished.where(updated_at: ...KEEP_FINISHED_FOR.ago).in_batches.delete_all
  end
end
