# Decides what the customer sees for one Captain V2 run: the answer (prose, citations, suggestion buttons or the
# empty-answer fallback) and the product cards. Returns message payloads and writes nothing, so a chat persists
# them and the playground only shows them.
class Captain::Conversation::ReplyComposer
  attr_reader :assistant, :conversation, :response, :run_result, :customer_message

  def initialize(assistant:, response:, run_result:, conversation: nil, customer_message: nil)
    @assistant = assistant
    @conversation = conversation
    @response = response
    @run_result = run_result
    @customer_message = customer_message
  end

  # suppress_suggestions: the caller knows the run ends in a handoff (or the conversation already waits for a human).
  def messages(suppress_suggestions: false)
    [answer_message(suppress_suggestions)] + cards_builder.build_messages(agent_name: response['agent_name'])
  end

  def empty_response?
    formatted_prose.blank? && !catalog_searches_empty? && !customer_message_has_attachments? && !model_returned_answer?
  end

  private

  def answer_message(suppress_suggestions)
    response_parts = Captain::Assistant::ResponseParts.from_response(response)
    content = formatted_prose
    if content.blank?
      content = empty_reply_fallback_text
      response_parts = Captain::Assistant::ResponseParts.new([{ 'text' => content, 'citation_indexes' => [] }])
    end

    {
      content: content,
      content_type: 'text',
      additional_attributes: answer_attributes(response_parts)
    }.merge(suggestion_buttons(content, suppress_suggestions))
  end

  def answer_attributes(response_parts)
    attributes = {}
    attributes[:agent_name] = response['agent_name'] if response['agent_name'].present?
    attributes[Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY] = response_parts.to_a
    attributes
  end

  def formatted_prose
    @formatted_prose ||= begin
      citation_urls = cards_builder.filter_citation_urls(assistant.trusted_citation_urls(run_result))
      cards_builder.clean_prose_content(
        Captain::Assistant::ResponseParts.from_response(response).customer_message_content(citation_urls: citation_urls)
      )
    end
  end

  def cards_builder
    @cards_builder ||= Captain::Conversation::ProductCardsBuilder.new(
      assistant: assistant, conversation: conversation, response: response, run_result: run_result
    )
  end

  def suggestion_buttons(content, suppress_suggestions)
    suggestions = suggested_replies
    return {} if suggestions.blank? || suppress_suggestions || contains_links?(content) || contains_cards?

    # submit_value: a click sends the item's value (the full question), while the button shows its short title.
    {
      content_type: 'input_select',
      content_attributes: { items: suggestions, submit_value: true }
    }
  end

  def suggested_replies
    raw = response.is_a?(Hash) ? response['suggested_replies'] : nil
    Array(raw).filter_map { |item| clean_suggestion_item(item) }.take(assistant.max_suggested_replies)
  end

  # Model output is { label, message }; older runs and scenario output may still be a plain string.
  def clean_suggestion_item(item)
    label, message = item.is_a?(Hash) ? item.values_at('label', 'message') : [item, nil]
    label = label.to_s.strip
    return if label.blank? || label.length > Captain::ResponseSchema::SUGGESTION_LABEL_MAX_LENGTH

    message = message.to_s.strip.first(Captain::ResponseSchema::SUGGESTION_MESSAGE_MAX_LENGTH).presence || label
    { 'title' => label, 'value' => message }
  end

  def contains_links?(content)
    content.to_s.match?(%r{https?://|\[.*?\]\(.*?\)}i)
  end

  def contains_cards?
    return true if cards_builder.has_products?

    response.is_a?(Hash) && (response['cards'].present? || response['content_type'] == 'cards')
  end

  def empty_reply_fallback_text
    I18n.with_locale(assistant.account.locale) do
      if catalog_searches_empty?
        I18n.t('conversations.captain.empty_response_catalog_empty')
      elsif customer_message_has_attachments?
        I18n.t('conversations.captain.empty_response_attachments')
      elsif model_returned_answer?
        I18n.t('conversations.captain.empty_response_unusable')
      else
        I18n.t('conversations.captain.empty_response_handoff')
      end
    end
  end

  def catalog_searches_empty?
    stats = assistant.run_result_product_search_stats(run_result)
    return false if stats.blank?

    stats[:searches].positive? && stats[:results].zero?
  end

  def customer_message_has_attachments?
    customer_message.respond_to?(:attachments) && customer_message.attachments.any?
  end

  def model_returned_answer?
    raw_response = response.is_a?(Hash) ? (response['response'] || response[:response]) : response.to_s
    response_parts_text = Captain::Assistant::ResponseParts.from_response(response).plain_text
    raw_response.to_s.strip.present? || response_parts_text.strip.present?
  end
end
