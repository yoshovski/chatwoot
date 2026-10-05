class Captain::Dify::DeleteFaqJob < ApplicationJob
  queue_as :default

  retry_on Dify::KnowledgeClient::Error, wait: 3.seconds, attempts: 15 do |job, error|
    Rails.logger.error("Dify FAQ delete failed response_id=#{job.arguments.first} error=#{error.class.name} status=#{error.status}")
  end

  def perform(_response_id, account_id, dataset_id, document_id)
    Account.find(account_id).dify_knowledge_client.delete_document(dataset_id: dataset_id, document_id: document_id)
  rescue Dify::KnowledgeClient::Error => e
    raise unless e.status == 404
  end
end
