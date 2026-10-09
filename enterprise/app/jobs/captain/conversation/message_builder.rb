module Captain::Conversation::MessageBuilder
  private

  def collect_previous_messages
    @conversation.messages.where(message_type: [:incoming, :outgoing], private: false).flat_map do |message|
      message_hash = {
        content: prepare_multimodal_message_content(message),
        role: determine_role(message)
      }
      message_hash[:agent_name] = message.additional_attributes['agent_name'] if message.additional_attributes&.dig('agent_name').present?

      result = [message_hash]
      result << { role: 'user', content: message.selected_option_text } if message.selected_option_text.present?
      result
    end
  end

  def determine_role(message)
    message.message_type == 'incoming' ? 'user' : 'assistant'
  end

  def prepare_multimodal_message_content(message)
    Captain::OpenAiMessageBuilderService.new(message: message).generate_content
  end

  def create_messages(preserve_waiting_since: false)
    return create_v1_message(preserve_waiting_since: preserve_waiting_since) unless captain_v2_enabled?

    answer, *cards = reply_composer.messages(suppress_suggestions: waiting_for_human? || handoff_active_or_requested?)
    validate_message_content!(answer[:content])
    primary_message = create_composed_message(answer, preserve_waiting_since: preserve_waiting_since)
    cards.each { |payload| create_composed_message(payload, preserve_waiting_since: preserve_waiting_since) }
    primary_message
  end

  def reply_composer
    Captain::Conversation::ReplyComposer.new(
      assistant: @assistant,
      conversation: @conversation,
      response: @response,
      run_result: @run_result,
      customer_message: responding_to_customer_message
    )
  end

  def create_v1_message(preserve_waiting_since: false)
    sanitizer = Captain::Conversation::ReplySanitizer.new(assistant: @assistant)
    content = sanitizer.sanitize_prose(@response['response'])
    validate_message_content!(content)
    create_outgoing_message(content, agent_name: @response['agent_name'], preserve_waiting_since: preserve_waiting_since)
  end

  def validate_message_content!(content)
    raise ArgumentError, 'Message content cannot be blank' if content.blank?
  end

  def create_outgoing_message(message_content, agent_name: nil, preserve_waiting_since: false)
    additional_attrs = agent_name.present? ? { agent_name: agent_name } : {}
    create_composed_message({ content: message_content, additional_attributes: additional_attrs }, preserve_waiting_since: preserve_waiting_since)
  end

  def create_composed_message(payload, preserve_waiting_since: false)
    @conversation.messages.create!(
      payload.merge(
        message_type: :outgoing,
        account_id: account.id,
        inbox_id: inbox.id,
        sender: @assistant,
        preserve_waiting_since: preserve_waiting_since
      )
    )
  end

  def handoff_active_or_requested?
    try(:v2_handoff_tool_fired?) || try(:v1_handoff_requested?) || try(:v2_handoff_tool_completed?) || try(:v2_handoff_declared?)
  end

  def waiting_for_human?
    try(:delegate_ownership_service)&.waiting?
  end
end
