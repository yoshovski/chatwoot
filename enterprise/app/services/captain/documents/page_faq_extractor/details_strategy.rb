class Captain::Documents::PageFaqExtractor::DetailsStrategy
  def initialize(extractor, node)
    @extractor = extractor
    @node = node
  end

  def extract
    faqs = []
    @node.css('details').each do |details|
      next if @extractor.consumed?(details)

      candidate = build_candidate(details)
      next unless candidate

      @extractor.consume!(details)
      faqs << candidate
    end
    faqs
  end

  private

  def build_candidate(details)
    summary = details.at_css('> summary') || details.at_css('summary')
    return nil unless summary

    q_text = summary.text.strip
    return nil if q_text.blank?

    a_md = extract_details_answer(details)
    return nil if a_md.blank?

    {
      question: q_text,
      answer: a_md,
      node: details,
      elements: [details]
    }
  end

  def extract_details_answer(details)
    details_copy = details.dup
    sum_copy = details_copy.at_css('> summary') || details_copy.at_css('summary')
    sum_copy&.remove

    @extractor.html_to_markdown(details_copy.inner_html)
  end
end
