# Check-in facts derived from the conversation's messages; nothing is stored on the conversation.
class Captain::Conversation::CheckInState
  ATTRIBUTE_KEY = 'captain_initiated'.freeze
  CHECK_IN = 'check_in'.freeze

  def initialize(conversation:, assistant:)
    @conversation = conversation
    @assistant = assistant
  end

  def last_public_message
    public_messages.reorder(id: :desc).first
  end

  # The agent spoke last, so a check-in fits; the visitor's or a colleague's message is never followed by one.
  def assistant_spoke_last?
    message = last_public_message
    message.present? && message.outgoing? && message.sender == @assistant
  end

  def checked_in_this_quiet_period?
    initiated = initiated_messages
    last_incoming_id = public_messages.incoming.maximum(:id)
    initiated = initiated.where('messages.id > ?', last_incoming_id) if last_incoming_id
    initiated.exists?
  end

  # The latest public message is a check-in or lead offer the visitor hasn't answered.
  def unanswered_check_in?
    message = last_public_message
    message.present? && message.outgoing? && message.additional_attributes.to_h[ATTRIBUTE_KEY].present?
  end

  # The last public messages as chat roles, oldest first, for the check-in and lead offer prompts.
  def recent_history(limit = Captain::Behaviour::CHECK_IN_HISTORY_MESSAGES)
    public_messages.reorder(id: :desc).limit(limit).to_a.reverse.filter_map do |message|
      content = message.content_for_llm
      { role: message.incoming? ? 'user' : 'assistant', content: content } if content.present?
    end
  end

  private

  def public_messages
    @conversation.messages.where(message_type: [:incoming, :outgoing], private: false)
  end

  def initiated_messages
    @conversation.messages.outgoing.where(sender: @assistant).where('messages.additional_attributes ? :key', key: ATTRIBUTE_KEY)
  end
end
