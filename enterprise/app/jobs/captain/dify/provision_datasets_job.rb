class Captain::Dify::ProvisionDatasetsJob < ApplicationJob
  queue_as :low

  # Dataset creation validates the embedding provider while holding the assistant
  # lock. Concurrent imports can outlast PostgreSQL's lock/statement timeout.
  retry_on ActiveRecord::LockWaitTimeout, ActiveRecord::QueryCanceled, wait: 30.seconds, attempts: 5
  retry_on Dify::KnowledgeClient::Error, wait: :polynomially_longer, attempts: 8 do |job, error|
    # Without datasets nothing can sync; say so on every document still waiting for its first upload.
    Captain::Document.where(assistant_id: job.arguments.first).where("metadata->>'dify_document_id' IS NULL")
                     .find_each { |document| document.mark_dify_sync_failed!("dify_provisioning_#{error.status || 'error'}") }
    Rails.logger.error("Dify dataset provisioning failed assistant_id=#{job.arguments.first} status=#{error.status}")
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(assistant_id)
    assistant = Captain::Assistant.find(assistant_id)
    assistant.ensure_dify_datasets!
    # A document job may have exhausted its own retries while initial KB setup
    # was unavailable. Recover only this agent's not-yet-uploaded source content.
    assistant.documents.enabled.where("metadata->>'dify_document_id' IS NULL").where.not(content: [nil, '']).find_each do |document|
      Captain::Dify::SyncDocumentJob.perform_later(document.id)
    end
  end
end
