# One reply while the policies shape it: the draft, the segments so far and the run's evidence (cited pages, knowledge
# media, cards) that every policy formats with. Writes nothing.
class Captain::Reply::Workspace
  attr_reader :context, :draft
  # greeting: the welcome part opening the first bubble. question: { text:, part_index: } of the closing question.
  # closing: the last segment is the closing bubble (the question and the buttons after the answer).
  attr_accessor :segments, :greeting, :question, :has_closing_question, :buttons, :closing

  delegate :assistant, :conversation, :run_result, to: :context

  def initialize(context, draft)
    @context = context
    @draft = draft
    @segments = []
  end

  # The welcome and the model's parts, citing the matching page when the model cited none; the product name is in every title.
  def answer_parts
    @answer_parts ||= begin
      parts = [greeting, *draft.parts].compact
      cited = response_parts(parts).with_fallback_citation(
        citation_titles: citation_titles.slice(*citation_urls.keys), ignored_words: assistant.product_name.to_s.split
      ).to_a
      parts.zip(cited).map { |part, cited_part| part.with(citation_indexes: cited_part['citation_indexes']) }
    end
  end

  def formatted_prose
    @formatted_prose ||= format(answer_parts)
  end

  # media: false leaves the knowledge videos and screenshots to the last bubble of a split reply.
  def format(parts, media: true)
    content = response_parts(parts).customer_message_content(citation_urls: citation_urls, citation_titles: citation_titles,
                                                             sources_format: sources_format)
    content = Captain::Knowledge::OfferingLinks.new(assistant).perform(content)
    content = with_knowledge_media(content) if media
    cards_builder.clean_prose_content(grounded_screenshots(content))
  end

  # A prose segment's text: fixed (the empty-answer fallback) or formatted from its parts.
  def text(segment)
    segment.text || format(segment.parts, media: segment.media)
  end

  # Shown under the bubble by the widget and playground; text channels already carry them in the content.
  def sources(parts)
    return [] unless sources_format == :structured

    response_parts(parts).sources(citation_urls: citation_urls, citation_titles: citation_titles)
  end

  def answer_segment(parts, sources:, media: true, text: nil)
    content_attributes = { Captain::Assistant::ResponseParts::SOURCES_ATTRIBUTE_KEY => sources } if sources.present?
    Captain::Reply::Segment.new(kind: 'answer', text: text, parts: parts, content_type: 'text', content_attributes: content_attributes,
                                additional_attributes: answer_attributes, media: media)
  end

  def answer_index = segments.rindex { |segment| segment.kind == 'answer' }

  # Takes the closing question out of the part it came from. False when nothing of the answer would remain.
  def remove_question!
    index = answer_index
    parts = segments[index].parts.each_with_index.filter_map do |part, part_index|
      part_index == question[:part_index] ? without_question(part) : part
    end
    segments[index] = segments[index].with(parts: parts, text: nil)
    text(segments[index]).present?
  end

  # The closing question moves to its own bubble after the answer; without a question the bubble only carries the
  # buttons. When nothing of the answer remains, the question takes the answer's place.
  def close_with_question!
    index = answer_index
    if question.nil? || remove_question!
      segments.insert(index + 1, question_segment)
    else
      question_part = Captain::Reply::Part.new(text: question[:text])
      segments[index] = segments[index].with(kind: 'question', parts: [question_part], media: true)
      segments.push(segments.delete_at(index))
    end
    self.closing = true
  end

  def with_buttons(segment)
    segment.with(content_type: 'input_select', content_attributes: segment.content_attributes.to_h.merge(buttons))
  end

  def without_buttons(segment)
    segment.with(content_type: 'text', content_attributes: segment.content_attributes.except(*buttons.keys).presence)
  end

  def contains_cards?
    return true if order_card_payloads.any? || cards_builder.has_products?

    draft.raw.is_a?(Hash) && (draft.raw['cards'].present? || draft.raw['content_type'] == 'cards')
  end

  def order_card_payloads
    @order_card_payloads ||= Captain::Conversation::OrderCardBuilder.new(assistant: assistant, run_result: run_result).build_messages
  end

  def product_card_payloads
    @product_card_payloads ||= cards_builder.build_messages(agent_name: draft.agent_name)
  end

  def structured_sources
    sources(answer_parts)
  end

  private

  def question_segment
    text = Captain::Knowledge::OfferingLinks.new(assistant).perform(question[:text]) if question
    Captain::Reply::Segment.new(kind: 'question', text: text,
                                additional_attributes: draft.agent_name.present? ? { agent_name: draft.agent_name } : {})
  end

  # nil when nothing of the part remains.
  def without_question(part)
    text = Captain::Assistant::ResponseParts.new([{ text: part.text.sub(question[:text], '') }]).parts.first&.fetch('text')
    part.with(text: text) if text
  end

  def answer_attributes
    attributes = {}
    attributes[:agent_name] = draft.agent_name if draft.agent_name.present?
    attributes[Captain::Leads::QuestionBudget::ATTRIBUTE_KEY] = true if !context.followup_form_requested && draft.qualification_question
    attributes
  end

  def response_parts(parts)
    Captain::Assistant::ResponseParts.new(parts.map(&:to_response_part))
  end

  def sources_format
    @sources_format ||= Captain::Assistant::ResponseParts.sources_format(conversation, sources_card: assistant.citations_enabled?)
  end

  def citation_titles
    @citation_titles ||= assistant.citation_titles(run_result)
  end

  def citation_urls
    @citation_urls ||= cards_builder.filter_citation_urls(assistant.trusted_citation_urls(run_result))
  end

  # A cited passage's instructional media must not disappear just because generation omitted its link.
  # Use only media in the retrieved excerpt of a source the answer actually uses, with bounded counts.
  def with_knowledge_media(content)
    return content if draft.handoff_requested

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
    indexes = answer_parts.flat_map(&:citation_indexes).uniq
    links = indexes.flat_map { |index| Array(media[index]) }.uniq
    videos, screenshots = links.partition { |link| Captain::Knowledge::VideoLink.line?(link) }
    # Screenshots are useful alongside actual steps, not a platform-selection or general factual answer.
    screenshots = [] unless response_parts(answer_parts).plain_text.match?(/^\s*\d+[.)]\s/)
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
      assistant: assistant, conversation: conversation, response: draft.raw, run_result: run_result
    )
  end
end
