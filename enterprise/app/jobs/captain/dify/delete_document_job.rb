class Captain::Dify::DeleteDocumentJob < ApplicationJob
  queue_as :low

  retry_on Dify::KnowledgeClient::Error, wait: 5.seconds, attempts: 5 do |job, error|
    Rails.logger.error("Dify document delete failed document_id=#{job.arguments.first} status=#{error.status}")
  end

  def perform(_document_id, account_id, dataset_id, dify_document_id)
    Account.find(account_id).dify_knowledge_client.delete_document(dataset_id: dataset_id, document_id: dify_document_id)
  rescue Dify::KnowledgeClient::Error => e
    raise unless e.status == 404
  end
end
