class Captain::Dify::UpdateDocumentStatusJob < ApplicationJob
  queue_as :low

  retry_on Dify::KnowledgeClient::Error, wait: 5.seconds, attempts: 5 do |job, error|
    Rails.logger.error("Dify document status update failed account_id=#{job.arguments[0]} status=#{error.status}")
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(account_id, dataset_id, action, document_ids)
    return if document_ids.blank?

    account = Account.find(account_id)
    return unless account.dify_knowledge_enabled?

    account.dify_knowledge_client.update_documents_status(
      dataset_id: dataset_id,
      action: action,
      document_ids: Array.wrap(document_ids)
    )
  rescue Dify::KnowledgeClient::Error => e
    raise unless e.status == 404
  end
end
