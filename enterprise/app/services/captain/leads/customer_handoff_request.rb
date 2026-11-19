# Check the visitor's own turn before interrupting an intake with required fields.
class Captain::Leads::CustomerHandoffRequest
  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def confirmed?(message)
    return false unless message

    previous = @conversation.messages.outgoing.where(private: false).where('id < ?', message.id).reorder(id: :desc).first
    history = []
    history << { role: 'assistant', content: previous.content } if previous
    history << { role: 'user', content: message.selected_option_text.presence || message.content }
    decision = Captain::Llm::AssistantActionClassifierService.new(assistant: @assistant, conversation: @conversation)
                                                             .classify(message_history: history, assistant_response: '')
    decision['action'] == 'handoff' && %w[explicit_human_request human_offer_accepted].include?(decision['action_reason'])
  end
end
