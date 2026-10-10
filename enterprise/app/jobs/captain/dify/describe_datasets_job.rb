# Refreshes the name and description of an AI agent's Dify datasets, e.g. after the agent or account is renamed.
class Captain::Dify::DescribeDatasetsJob < ApplicationJob
  queue_as :low

  def perform(assistant_id)
    assistant = Captain::Assistant.find_by(id: assistant_id)
    return unless assistant&.account&.dify_knowledge_enabled?

    identity = Captain::Dify::DatasetIdentity.new(assistant)
    Captain::Dify::DatasetIdentity::KINDS.each do |kind|
      dataset_id = assistant.config["dify_#{kind}_dataset_id"]
      describe(assistant, dataset_id, identity.attributes(kind)) if dataset_id.present?
    end
  end

  private

  def describe(assistant, dataset_id, attributes)
    assistant.account.dify_knowledge_client.update_dataset(dataset_id, **attributes)
  rescue Dify::KnowledgeClient::Error => e
    raise unless e.status == 404

    Rails.logger.warn("Dify dataset #{dataset_id} of assistant #{assistant.id} no longer exists")
  end
end
