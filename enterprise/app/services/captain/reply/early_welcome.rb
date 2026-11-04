# The router's welcome on the first web widget reply, posted as its own message before the answer while retrieval, the
# catalog and the action agent still work (the typing indicator stays on until the chat job ends). It is the
# conversation's only greeting: the main reply knows the visitor was welcomed, and the reply checks drop any other.
module Captain::Reply::EarlyWelcome
  KINDS = %w[greeting].freeze

  # Posts the welcome unless the conversation already has one (a burst of visitor messages runs one job per message),
  # the agent may no longer reply or a newer visitor message arrived (that message's run welcomes instead). True when
  # the conversation now has its welcome.
  def self.post(assistant:, conversation:, text:, responding_to_message_id: nil)
    Conversation.transaction do
      # The row lock makes concurrent runs of one conversation check and post one after the other.
      conversation = Conversation.lock.find(conversation.id)
      next true if sent?(conversation)

      content = Captain::Conversation::ReplySanitizer.new(assistant: assistant).sanitize_prose(text)
      ownership = Captain::Conversation::OwnershipService.new(conversation: conversation, assistant: assistant)
      next false if content.blank? || !ownership.may_reply? || newer_message?(conversation, responding_to_message_id)

      create(assistant, conversation, content, responding_to_message_id, preserve_waiting_since: ownership.waiting?)
      true
    end
  end

  # Whether a Captain message of the conversation already carried a greeting.
  def self.sent?(conversation)
    greetings(conversation).exists?
  end

  # The early welcome posted for the reply to this visitor message, whose pacing the reply continues.
  def self.posted_after(conversation, message)
    return unless message

    greetings(conversation).where('messages.id > ?', message.id).order(:id).last
  end

  def self.greetings(conversation)
    conversation.messages.where(message_type: :outgoing, sender_type: 'Captain::Assistant')
                .where('additional_attributes -> ? @> ?::jsonb', Captain::Reply::Plan::SEGMENT_KINDS_KEY, KINDS.to_json)
  end

  def self.newer_message?(conversation, message_id)
    message_id.present? && conversation.messages.captain_response_triggering.exists?(['messages.id > ?', message_id])
  end

  def self.create(assistant, conversation, content, responding_to_message_id, preserve_waiting_since:)
    responding_to = conversation.messages.find_by(id: responding_to_message_id) if responding_to_message_id
    responding_to ||= conversation.messages.incoming.last
    payload = { content: content, content_type: 'text', additional_attributes: { Captain::Reply::Plan::SEGMENT_KINDS_KEY => KINDS } }
    payload = Captain::Reply::Pacing.stamp([payload], responding_to: responding_to).first
    conversation.messages.create!(payload.merge(message_type: :outgoing, account_id: conversation.account_id, inbox_id: conversation.inbox_id,
                                                sender: assistant, preserve_waiting_since: preserve_waiting_since))
  end

  private_class_method :greetings, :newer_message?, :create
end
