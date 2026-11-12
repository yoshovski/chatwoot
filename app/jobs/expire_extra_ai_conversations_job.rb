class ExpireExtraAiConversationsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ExtraAiConversationEntry.expire!
  end
end
