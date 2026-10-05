class Captain::Dify::ProvisionDatasetsJob < ApplicationJob
  queue_as :low

  def perform(assistant_id)
    Captain::Assistant.find(assistant_id).ensure_dify_datasets!
  end
end
