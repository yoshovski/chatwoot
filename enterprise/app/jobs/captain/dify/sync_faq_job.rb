class Captain::Dify::SyncFaqJob < ApplicationJob
  queue_as :default

  retry_on Dify::KnowledgeClient::Error, wait: 3.seconds, attempts: 15 do |job, error|
    Rails.logger.error("Dify FAQ sync failed response_id=#{job.arguments.first} error=#{error.class.name} status=#{error.status}")
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(response_id)
    Captain::Dify::FaqSyncService.new(Captain::AssistantResponse.find(response_id)).perform
  end
end
