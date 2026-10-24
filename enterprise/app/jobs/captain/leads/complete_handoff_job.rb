class Captain::Leads::CompleteHandoffJob < ApplicationJob
  queue_as :medium
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5

  def perform(assistant_id, conversation_id)
    assistant = Captain::Assistant.find_by(id: assistant_id)
    return unless assistant

    conversation = assistant.account.conversations.find_by(id: conversation_id)
    return unless conversation

    Captain::Leads::HandoffCaptureService.new(conversation, assistant).complete!
  end
end
