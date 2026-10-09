module Captain::Dify::AssistantResponse
  extend ActiveSupport::Concern

  prepended do
    before_update :detach_dify_document_on_move
    after_update_commit :sync_dify_faq_status
  end

  private

  def detach_dify_document_on_move
    self.dify_document_id = nil if assistant_id_changed?
  end

  def update_response_embedding
    return enqueue_dify_delete(assistant, dify_document_id) if destroyed?

    delete_moved_dify_document if saved_change_to_assistant_id?
    return unless account.dify_knowledge_enabled?
    return if dify_document_id.present? && !saved_changes.keys.intersect?(%w[question answer assistant_id])

    Captain::Dify::SyncFaqJob.perform_later(id)
  end

  def delete_moved_dify_document
    document_id = saved_change_to_dify_document_id&.first
    return if document_id.blank?

    enqueue_dify_delete(Captain::Assistant.find(assistant_id_before_last_save), document_id)
  end

  def enqueue_dify_delete(source, document_id)
    return if document_id.blank? || source.nil?

    Captain::Dify::DeleteFaqJob.perform_later(id, account_id, source.config.fetch('dify_faq_dataset_id'), document_id)
  end

  def sync_dify_faq_status
    return unless saved_change_to_enabled?
    return unless account.dify_knowledge_enabled?
    return if dify_document_id.blank? || assistant.nil?

    action = enabled? ? 'enable' : 'disable'
    Captain::Dify::UpdateDocumentStatusJob.perform_later(
      account_id,
      assistant.config.fetch('dify_faq_dataset_id'),
      action,
      [dify_document_id]
    )
  end
end
