# Writes the Wants / Details / Next summary with the handoff prompt when the handoff note didn't (the agent gave its own
# reason) and when a conversation the AI took part in is resolved. Never counts toward the AI allowance.
class Captain::Conversation::SummaryJob < ApplicationJob
  queue_as :low

  def perform(conversation, status)
    text = Captain::Conversation::HandoffNoteService.new(conversation: conversation).generate_summary
    Captain::Conversation::Summary.new(conversation).update!({ 'status' => status }.merge(Captain::Conversation::Summary.parse(text)))
  end
end
