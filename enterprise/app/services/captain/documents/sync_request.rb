# Queues a refresh of one document, or a retry after a failed sync.
class Captain::Documents::SyncRequest
  def initialize(document)
    @document = document
  end

  # :queued, :unsupported (an uploaded file) or :not_ready (still being processed).
  def perform
    return retry_dify_sync if @document.dify_sync_retryable?
    return :unsupported unless @document.syncable?
    return :not_ready unless @document.available? || @document.sync_failed?

    mark_syncing
    # A website page whose first import failed has nothing to compare yet: import it again.
    if @document.content.blank? && @document.metadata.to_h['website_source_id'].present?
      Captain::Websites::ImportPageJob.perform_later(@document.id)
    else
      Captain::Documents::PerformSyncJob.perform_later(@document)
    end
    :queued
  end

  private

  # The page text is already stored; only sending it to Dify failed.
  def retry_dify_sync
    mark_syncing
    Captain::Dify::SyncDocumentJob.perform_later(@document.id)
    :queued
  end

  def mark_syncing
    @document.update!(sync_status: :syncing, sync_step: nil, last_sync_error_code: nil, last_sync_attempted_at: Time.current)
  end
end
