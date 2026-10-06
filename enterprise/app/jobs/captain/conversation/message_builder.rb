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

    response_parts = Captain::Assistant::ResponseParts.from_response(@response)
    citation_urls = @assistant.trusted_citation_urls(@run_result)
    message_content = response_parts.customer_message_content(citation_urls: citation_urls)
    validate_message_content!(message_content)

    suggestions = extract_suggested_replies
    extra_attrs = suggestion_button_attributes(message_content, suggestions)
    create_outgoing_message(message_content, agent_name: @response['agent_name'], response_parts: response_parts.to_a,
                                             preserve_waiting_since: preserve_waiting_since, extra_attrs: extra_attrs)
  end

  def create_v1_message(preserve_waiting_since: false)
    validate_message_content!(@response['response'])
    create_outgoing_message(@response['response'], agent_name: @response['agent_name'], preserve_waiting_since: preserve_waiting_since)
  end

  def validate_message_content!(content)
    raise ArgumentError, 'Message content cannot be blank' if content.blank?
  end

  def create_outgoing_message(message_content, agent_name: nil, response_parts: nil, preserve_waiting_since: false, extra_attrs: {})
    additional_attrs = {}
    additional_attrs[:agent_name] = agent_name if agent_name.present?
    additional_attrs[Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY] = response_parts unless response_parts.nil?

    @conversation.messages.create!(
      {
        message_type: :outgoing,
        account_id: account.id,
        inbox_id: inbox.id,
        sender: @assistant,
        content: message_content,
        additional_attributes: additional_attrs,
        preserve_waiting_since: preserve_waiting_since
      }.merge(extra_attrs)
    )
  end

  def suggestion_button_attributes(message_content, suggestions)
    return {} unless eligible_for_suggestion_buttons?(message_content, suggestions)

    {
      content_type: 'input_select',
      content_attributes: { items: suggestions.map { |text| { 'title' => text, 'value' => text } } }
    }
  end

  def extract_suggested_replies
    raw = @response.is_a?(Hash) ? @response['suggested_replies'] : nil
    Array(raw).filter_map { |item| clean_suggestion_item(item) }.take(@assistant.max_suggested_replies)
  end

  def clean_suggestion_item(item)
    text = item.is_a?(Hash) ? (item['title'] || item['value']) : item.to_s
    clean = text.to_s.strip
    clean.presence && clean.length <= 80 ? clean : nil
  end

  def eligible_for_suggestion_buttons?(message_content, suggestions)
    return false if suggestions.blank? || waiting_for_human? || handoff_active_or_requested?
    return false if contains_links?(message_content) || contains_cards?

    true
  end

  def handoff_active_or_requested?
    try(:v2_handoff_tool_fired?) || try(:v1_handoff_requested?) || try(:v2_handoff_tool_completed?)
  end

  def waiting_for_human?
    try(:delegate_ownership_service)&.waiting?
  end

  def contains_links?(content)
    content.to_s.match?(%r{https?://|\[.*?\]\(.*?\)}i)
  end

  def contains_cards?
    @response.is_a?(Hash) && (@response['cards'].present? || @response['content_type'] == 'cards')
  end
end
