class Captain::Dify::ReconcileJob < ApplicationJob
  queue_as :low

  retry_on Dify::KnowledgeClient::Error, wait: 30.seconds, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(assistant_id)
    Captain::Dify::ReconcileService.new(Captain::Assistant.find(assistant_id)).perform
  end
end
