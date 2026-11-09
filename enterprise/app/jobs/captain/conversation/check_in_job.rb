# frozen_string_literal: true

# Proactive check-in job scheduled after an AI reply on web widgets.
# Sends one short check-in if the visitor has gone quiet during the quiet period.
class Captain::Conversation::CheckInJob < ApplicationJob
  queue_as :low

  def perform(conversation_id, assistant_id)
    conversation = ::Conversation.find_by(id: conversation_id)
    assistant = Captain::Assistant.find_by(id: assistant_id)
    return unless conversation && assistant
    return unless assistant.account.feature_enabled?('captain_integration_v2')

    Captain::Conversation::CheckInRunner.new(inbox: conversation.inbox, assistant: assistant).check_in(conversation, proactive: true)
  end
end
