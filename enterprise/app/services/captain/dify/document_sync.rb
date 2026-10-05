module Captain::Dify::DocumentSync
  private

  def mark_synced
    return super unless @document.account.dify_knowledge_enabled?
    return super if @document.dify_indexing_status == 'completed'

    @document.update!(status: :in_progress, sync_status: :syncing, sync_step: nil, last_sync_attempted_at: Time.current)
    Captain::Dify::SyncDocumentJob.perform_later(@document.id)
  end
end
