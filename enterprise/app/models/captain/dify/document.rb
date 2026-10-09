module Captain::Dify::Document
  extend ActiveSupport::Concern

  prepended do
    store_accessor :metadata, :dify_document_id, :dify_indexing_status, :dify_content_fingerprint
    before_save :mark_dify_indexing_pending
    after_update_commit :sync_dify_document_status
    after_destroy_commit :delete_dify_document
  end

  def dify_source_fingerprint
    return "pdf:#{pdf_file.blob.checksum}" if pdf_document?

    "sectioned-v2:#{Digest::SHA256.hexdigest(dify_sectioned_content)}"
  end

  def dify_sectioned_content
    Captain::Knowledge::SectionedText.new(content, title: name).to_s
  end

  def knowledge_state
    return unless account.dify_knowledge_enabled?
    return 'paused' unless enabled?
    return 'searchable' if available? && dify_indexing_status == 'completed'
    return 'not_searchable' if dify_indexing_status == 'error' || sync_failed?

    'indexing'
  end

  def mark_dify_sync_failed!(error_code)
    update!(status: :in_progress, sync_status: :failed, dify_indexing_status: 'error', sync_step: nil,
            last_sync_error_code: error_code, last_sync_attempted_at: Time.current)
  end

  private

  def mark_dify_indexing_pending
    return unless account.dify_knowledge_enabled? || pdf_document?
    return unless (content_changed? && content.present?) || (new_record? && pdf_document?)

    self.status = :in_progress
    self.sync_status = :syncing
    self.dify_indexing_status = 'waiting'
    self.sync_step = nil
    self.last_sync_error_code = nil
    self.last_synced_at = last_synced_at_was
  end

  def enqueue_crawl_job
    return if content.present? && account.dify_knowledge_enabled?

    super
  end

  def enqueue_response_builder_job
    return if pdf_document?
    return super unless account.dify_knowledge_enabled?
    return if destroyed? || !saved_change_to_content? || content.blank?

    Captain::Dify::SyncDocumentJob.perform_later(id)
  end

  def delete_dify_document
    return if dify_document_id.blank? || assistant.nil?

    Captain::Dify::DeleteDocumentJob.perform_later(id, account_id, assistant.config.fetch('dify_docs_dataset_id'), dify_document_id)
  end

  def sync_dify_document_status
    return unless saved_change_to_enabled?
    return unless account.dify_knowledge_enabled?
    return if dify_document_id.blank? || assistant.nil?

    action = enabled? ? 'enable' : 'disable'
    Captain::Dify::UpdateDocumentStatusJob.perform_later(
      account_id,
      assistant.config.fetch('dify_docs_dataset_id'),
      action,
      [dify_document_id]
    )
    sync_dify_child_faq_status(action)
  end

  def sync_dify_child_faq_status(action)
    faq_dataset_id = assistant.config['dify_faq_dataset_id']
    return if faq_dataset_id.blank?

    scope = responses.where.not(dify_document_id: nil)
    scope = scope.where(enabled: true) if enabled?
    faq_ids = scope.pluck(:dify_document_id)
    return if faq_ids.blank?

    Captain::Dify::UpdateDocumentStatusJob.perform_later(
      account_id,
      faq_dataset_id,
      action,
      faq_ids
    )
  end
end
