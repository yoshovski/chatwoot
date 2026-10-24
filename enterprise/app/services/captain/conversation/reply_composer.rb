# Decides what the customer sees for one Captain V2 run: the answer (prose, citations, suggestion buttons or the
# empty-answer fallback), the order card and the product cards. With product cards, a closing question and its buttons
# move below the cards. Returns message payloads and writes nothing, so a chat persists them and the playground only shows them.
class Captain::Conversation::ReplyComposer
  # The last sentence of the prose when it is a question that follows at least one other sentence.
  TRAILING_QUESTION = /(?<=[.!?])\s+([^\n.!?]+\?)\s*\z/
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
    content, response_parts = answer_content
    buttons = suggestion_buttons(suppress_suggestions)
    return composed_messages(answer_message(content, response_parts, buttons)) unless contains_cards?

    # With cards, buttons only answer a closing question, shown below the cards: intro, cards, then the question.
    question = content[TRAILING_QUESTION, 1] if buttons.present?
    return composed_messages(answer_message(content, response_parts, {})) unless question

    content = content.delete_suffix(content[TRAILING_QUESTION]).strip
    response_parts = without_trailing_question(response_parts, question)
    composed_messages(answer_message(content, response_parts, {})) << question_message(question, buttons)
  end

  def empty_response?
    formatted_prose.blank? && !catalog_searches_empty? && !customer_message_has_attachments? && !model_returned_answer?
  end

  private

  def composed_messages(answer)
    [answer] +
      Captain::Conversation::OrderCardBuilder.new(assistant: assistant, run_result: run_result).build_messages +
      cards_builder.build_messages(agent_name: response['agent_name'])
  end

  def answer_content
    content = formatted_prose
    return [content, response_parts] if content.present?

    content = empty_reply_fallback_text
    [content, Captain::Assistant::ResponseParts.new([{ 'text' => content, 'citation_indexes' => [] }])]
  end

  def answer_message(content, response_parts, buttons)
    message = { content: content, content_type: 'text', additional_attributes: answer_attributes(response_parts) }.merge(buttons)
    return message if structured_sources.empty?

    message.merge(content_attributes: message.fetch(:content_attributes, {})
                                             .merge(Captain::Assistant::ResponseParts::SOURCES_ATTRIBUTE_KEY => structured_sources))
  end

  def sources_format
    @sources_format ||= Captain::Assistant::ResponseParts.sources_format(conversation, sources_card: assistant.citations_enabled?)
  end

  def citation_titles
    @citation_titles ||= assistant.citation_titles(run_result)
  end

  # The run's parts, citing the matching page when the model cited none; the product name is in every title.
  def response_parts
    @response_parts ||= Captain::Assistant::ResponseParts.from_response(response).with_fallback_citation(
      citation_titles: citation_titles.slice(*citation_urls.keys), ignored_words: assistant.product_name.to_s.split
    )
  end

  def citation_urls
    @citation_urls ||= cards_builder.filter_citation_urls(assistant.trusted_citation_urls(run_result))
  end

  # Shown under the bubble by the widget and playground; text channels already carry them in the content.
  def structured_sources
    return [] unless sources_format == :structured

    @structured_sources ||= response_parts.sources(citation_urls: citation_urls, citation_titles: citation_titles)
  end

  def question_message(question, buttons)
    attributes = response['agent_name'].present? ? { agent_name: response['agent_name'] } : {}
    { content: question, additional_attributes: attributes }.merge(buttons)
  end

  def without_trailing_question(response_parts, question)
    parts = response_parts.to_a.map(&:dup)
    parts.last['text'] = parts.last['text'].delete_suffix(question).strip
    Captain::Assistant::ResponseParts.new(parts)
  end

  def answer_attributes(response_parts)
    attributes = {}
    attributes[:agent_name] = response['agent_name'] if response['agent_name'].present?
    attributes[Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY] = response_parts.to_a
    attributes
  end

  def formatted_prose
    @formatted_prose ||= begin
      content = response_parts.customer_message_content(citation_urls: citation_urls, citation_titles: citation_titles,
                                                        sources_format: sources_format)
      cards_builder.clean_prose_content(grounded_screenshots(with_knowledge_media(content)))
    end
  end

  # A cited passage's instructional media must not disappear just because generation omitted its link.
  # Use only media in the retrieved excerpt of a source the answer actually uses, with bounded counts.
  def with_knowledge_media(content)
    return content if response['handoff_requested'] == true

    knowledge_media_links.reduce(content) do |body, link|
      url = link[Captain::Conversation::ReplySanitizer::MARKDOWN_LINK_REGEX, 2]
      text = body.gsub(Captain::Conversation::ReplySanitizer::MARKDOWN_LINK_REGEX) do |existing|
        Regexp.last_match(2) == url ? '' : existing
      end
      "#{text.strip}\n\n#{link}"
    end
  end

  def knowledge_media_links
    media = run_result&.context&.dig(:state, :knowledge_media).to_h
    indexes = response_parts.to_a.flat_map { |part| part['citation_indexes'] }.uniq
    links = indexes.flat_map { |index| Array(media[index]) }.uniq
    videos, screenshots = links.partition { |link| Captain::Knowledge::VideoLink.line?(link) }
    # Screenshots are useful alongside actual steps, not a platform-selection or general factual answer.
    screenshots = [] unless response_parts.plain_text.match?(/^\s*\d+[.)]\s/)
    videos.first(1) + screenshots.first(2)
  end

  # A stored Shopify-only default must not hide documentation screenshots. Custom image rules still
  # apply, and every screenshot must have occurred in this turn's retrieved evidence.
  def grounded_screenshots(content)
    urls = Array(run_result&.context&.dig(:state, :knowledge_screenshots))
    sanitizer = Captain::Conversation::ReplySanitizer.new(assistant: assistant)
    default_images = assistant.image_allowlist == assistant.default_image_allowlist
    content.gsub(Captain::Knowledge::ScreenshotLink::LINE) do |link|
      url = Regexp.last_match(2)
      allowed = default_images || sanitizer.allowed_image_url?(url)
      urls.include?(url) && allowed ? link : ''
    end
  end

  def cards_builder
    @cards_builder ||= Captain::Conversation::ProductCardsBuilder.new(
      assistant: assistant, conversation: conversation, response: response, run_result: run_result
    )
  end

  def suggestion_buttons(suppress_suggestions)
    suggestions = suggested_replies
    return {} if suggestions.blank? || suppress_suggestions

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
    return if label.blank?

    message = (message.to_s.strip.presence || label).first(Captain::ResponseSchema::SUGGESTION_MESSAGE_MAX_LENGTH)
    label = label.truncate(Captain::ResponseSchema::SUGGESTION_LABEL_MAX_LENGTH)
    { 'title' => label, 'value' => message }
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
