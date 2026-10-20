# Removes a deleted AI agent's own Dify dataset, so an agent created later with the same name can
# create its datasets. A dataset another agent still uses is kept.
class Captain::Dify::DeleteDatasetJob < ApplicationJob
  queue_as :low

  retry_on Dify::KnowledgeClient::Error, wait: :polynomially_longer, attempts: 5 do |job, error|
    Rails.logger.error("Dify dataset delete failed account_id=#{job.arguments.first} status=#{error.status}")
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(account_id, dataset_id)
    return if Captain::Dify::DatasetReferences.referenced?(dataset_id)

    Account.find(account_id).dify_knowledge_client.delete_dataset(dataset_id)
  rescue Dify::KnowledgeClient::Error => e
    raise unless e.status == 404
  end
end
