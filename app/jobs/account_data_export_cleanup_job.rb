class AccountDataExportCleanupJob < ApplicationJob
  queue_as :low

  def perform(export)
    export.archive.purge if export.expires_at <= Time.current
  end
end
