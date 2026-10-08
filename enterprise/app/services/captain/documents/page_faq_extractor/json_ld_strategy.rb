class Captain::Documents::PageFaqExtractor::JsonLdStrategy
  def initialize(extractor, doc)
    @extractor = extractor
    @doc = doc
  end

  def extract
    faqs = []
    @doc.css('script[type="application/ld+json"]').each do |script|
      content = script.text.strip
      next if content.blank?

      extract_from_script(script, content, faqs)
    end
    faqs
  end

  private

  def extract_from_script(script, content, faqs)
    parsed = JSON.parse(content)
    find_faq_pages(parsed).each do |page|
      extract_page_entities(script, page, faqs)
    end
  rescue JSON::ParserError
    nil
  end

  def extract_page_entities(script, page, faqs)
    entities = Array(page['mainEntity'])
    entities.each do |entity|
      next unless entity.is_a?(Hash)

      candidate = build_candidate(script, entity)
      faqs << candidate if candidate
    end
  end

  def build_candidate(script, entity)
    q_name = entity['name']
    a_text = resolve_accepted_answer(entity['acceptedAnswer'])
    return nil if q_name.blank? || a_text.blank?

    {
      question: q_name.to_s.strip,
      answer: @extractor.html_to_markdown(a_text),
      node: script,
      elements: []
    }
  end

  def resolve_accepted_answer(accepted)
    if accepted.is_a?(Hash)
      accepted['text']
    elsif accepted.is_a?(Array)
      accepted.filter_map { |a| a['text'] if a.is_a?(Hash) }.join("\n\n")
    end
  end

  def find_faq_pages(data)
    items = if data.is_a?(Array)
              data
            elsif data.is_a?(Hash)
              data['@graph'].is_a?(Array) ? data['@graph'] : [data]
            else
              []
            end

    items.select { |item| item.is_a?(Hash) && faq_type?(item['@type']) }
  end

  def faq_type?(type)
    if type.is_a?(Array)
      type.any? { |t| t.to_s.end_with?('FAQPage') }
    else
      type.to_s.end_with?('FAQPage')
    end
  end
end
