# Polling gives up after about two hours, but Dify keeps indexing. Documents marked as timed out are
# checked again on every scheduler run and become Ready once Dify has finished them.
class Captain::Dify::RecheckTimedOutDocumentsJob < ApplicationJob
  queue_as :low
  BATCH_SIZE = 200
  WINDOW = 7.days

  def perform
    timed_out_documents.each { |document| recheck(document) }
  end

  private

  def timed_out_documents
    Captain::Document.sync_failed
                     .where("captain_documents.metadata->>'last_sync_error_code' = ?", 'dify_indexing_timeout')
                     .where("captain_documents.metadata->>'dify_document_id' IS NOT NULL")
                     .where(updated_at: WINDOW.ago..)
                     .includes(:account, :assistant)
                     .order(:id)
                     .limit(BATCH_SIZE)
  end

  def recheck(document)
    return unless document.account.dify_knowledge_enabled?

    dataset_id = document.assistant.config.fetch('dify_docs_dataset_id')
    state = document.account.dify_knowledge_client.document(dataset_id: dataset_id, document_id: document.dify_document_id)
    import_page_faqs = document.with_lock do
      next false unless document.last_sync_error_code == 'dify_indexing_timeout'

      apply(document, state)
    end
    Captain::Documents::ResponseBuilderJob.perform_later(document) if import_page_faqs
  rescue Dify::KnowledgeClient::Error => e
    Rails.logger.warn("Dify timeout recheck failed document_id=#{document.id} status=#{e.status}")
  end

  def apply(document, state)
    case state.fetch('indexing_status')
    when 'completed' then Captain::Dify::DocumentCompletion.new(document, state).apply
    when 'error'
      document.mark_dify_sync_failed!('dify_indexing_failed')
      false
    else
      false
    end
  end
end
