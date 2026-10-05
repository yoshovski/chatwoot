class Captain::Dify::PollDocumentJob < ApplicationJob
  queue_as :low
  MAX_POLLS = 120

  retry_on Dify::KnowledgeClient::Error, wait: 5.seconds, attempts: 5 do |job, error|
    Captain::Document.find_by(id: job.arguments.first)&.mark_dify_sync_failed!("dify_http_#{error.status || 'error'}")
    Rails.logger.error("Dify document polling failed document_id=#{job.arguments.first} status=#{error.status}")
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(document_id, dify_document_id, fingerprint, poll = 0)
    document = Captain::Document.find(document_id)
    unless document.account.dify_knowledge_enabled?
      document.mark_dify_sync_failed!('dify_not_configured')
      return
    end

    dataset_id = Captain::Assistant.find(document.assistant_id).config.fetch('dify_docs_dataset_id')
    state = document.account.dify_knowledge_client.document(dataset_id: dataset_id, document_id: dify_document_id)
    generate_faqs = document.with_lock do
      return unless document.dify_document_id == dify_document_id && document.dify_source_fingerprint == fingerprint
      return if document.available? && document.dify_indexing_status == 'completed'

      apply_state(document, state, fingerprint, poll)
    end
    Captain::Documents::ResponseBuilderJob.perform_later(document) if generate_faqs
  end

  private

  def apply_state(document, state, fingerprint, poll)
    status = state.fetch('indexing_status')
    return complete(document, state) if status == 'completed'

    if status == 'error'
      document.mark_dify_sync_failed!('dify_indexing_failed')
    elsif poll >= MAX_POLLS
      document.mark_dify_sync_failed!('dify_indexing_timeout')
    else
      document.update!(dify_indexing_status: status) unless document.dify_indexing_status == status
      self.class.set(wait: 5.seconds).perform_later(document.id, document.dify_document_id, fingerprint, poll + 1)
    end
    false
  end

  def complete(document, state)
    unless state.fetch('enabled') && !state.fetch('archived') && state.fetch('doc_form') == 'hierarchical_model'
      document.mark_dify_sync_failed!('dify_document_unavailable')
      return
    end

    document.update!(status: :available, sync_status: :synced, dify_indexing_status: 'completed', sync_step: nil,
                     last_sync_error_code: nil, last_synced_at: Time.current, last_sync_attempted_at: Time.current)
    !document.pdf_document?
  end
end
