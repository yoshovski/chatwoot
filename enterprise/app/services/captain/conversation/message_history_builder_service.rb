class Captain::Conversation::MessageHistoryBuilderService
  RESOLUTION_MARKER = '<conversation_boundary status="resolved" />'.freeze

  pattr_initialize [:conversation!]

  def perform(include_message_ids: false)
    conversation_messages_for_context.flat_map do |message|
      message_hash = message_hash_for_context(message)
      next [] if message_hash.blank?

      message_hash.merge!(source_attributes(message)) if include_message_ids
      agent_name = agent_name_for_context(message)
      message_hash[:agent_name] = agent_name if agent_name.present?
      result = [message_hash]
      if message.selected_option_text.present?
        result << message_hash.slice(:message_id, :source_digest).merge(role: 'user',
                                                                        content: message.selected_option_text)
      end
      result
    end
  end

  private

  def agent_name_for_context(message)
    name = message.additional_attributes&.dig('agent_name')
    # Forms in older releases stored the display name instead of the runtime identity.
    return name unless message.sender_type == 'Captain::Assistant' && name.present?

    sender = message.sender
    sender && name == sender.name ? sender.agent_name : name
  end

  def source_attributes(message)
    # Hash stable source fields, not expiring attachment URLs or delivery status.
    source = [message.content, message.deleted, message.content_type, message.selected_option_text,
              message.additional_attributes.to_h[Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY],
              message.content_attributes.to_h['activity'], message.attachments.map(&:id)]
    { message_id: message.id, source_digest: Digest::SHA256.hexdigest(source.to_json) }
  end

  def conversation_messages_for_context
    conversation.messages
                .includes(:attachments, :sender)
                .where(private: false, message_type: [:incoming, :outgoing, :activity])
                .reorder(created_at: :asc, id: :asc)
  end

  def message_hash_for_context(message)
    return activity_message_hash(message) if message.message_type == 'activity'

    content = prepare_multimodal_message_content(message)
    return if content.blank?

    {
      content: content,
      role: determine_role(message)
    }
  end

  def activity_message_hash(message)
    activity = message.content_attributes.to_h['activity'].to_h
    return unless activity['type'] == 'conversation_status_changed' && activity['status'] == 'resolved'

    {
      content: RESOLUTION_MARKER,
      role: 'assistant'
    }
  end

  def determine_role(message)
    message.message_type == 'incoming' ? 'user' : 'assistant'
  end

  def prepare_multimodal_message_content(message)
    if message.outgoing? && message.sender_type == 'Captain::Assistant' && !message.deleted
      message_attributes = message.additional_attributes.to_h
      response_parts_attribute = Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY
      if message_attributes.key?(response_parts_attribute)
        return Captain::Assistant::ResponseParts.new(message_attributes[response_parts_attribute]).plain_text.presence
      end
    end

    Captain::OpenAiMessageBuilderService.new(message: message).generate_content
  end
end
