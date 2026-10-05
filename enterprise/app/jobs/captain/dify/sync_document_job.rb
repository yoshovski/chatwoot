class Captain::Dify::SyncDocumentJob < ApplicationJob
  queue_as :low

  retry_on Dify::KnowledgeClient::Error, wait: 5.seconds, attempts: 5 do |job, error|
    document = Captain::Document.find_by(id: job.arguments.first)
    document&.mark_dify_sync_failed!("dify_http_#{error.status || 'error'}")
    Rails.logger.error("Dify document sync failed document_id=#{job.arguments.first} status=#{error.status}")
  end
  retry_on Captain::Dify::DocumentSyncService::IndexingPending, wait: 5.seconds, attempts: 120 do |job, _error|
    Captain::Document.find_by(id: job.arguments.first)&.mark_dify_sync_failed!('dify_indexing_timeout')
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(document_id)
    document = Captain::Document.find(document_id)
    unless document.account.dify_knowledge_enabled?
      document.mark_dify_sync_failed!('dify_not_configured')
      return
    end

    result = Captain::Dify::DocumentSyncService.new(document).perform
    Captain::Dify::PollDocumentJob.perform_later(document.id, *result) if result
  end
end
