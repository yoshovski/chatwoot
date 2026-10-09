class Captain::Documents::PageFaqExtractor::MicrodataStrategy
  def initialize(extractor, node)
    @extractor = extractor
    @node = node
  end

  def extract
    faqs = []
    @node.css('[itemtype$="schema.org/Question"]').each do |q_el|
      next if @extractor.consumed?(q_el)

      candidate = build_candidate(q_el)
      next unless candidate

      @extractor.consume!(q_el)
      faqs << candidate
    end
    faqs
  end

  private

  def build_candidate(q_el)
    name_el = q_el.at_css('[itemprop="name"]')
    return nil if name_el.blank?

    q_text = name_el.text.strip
    return nil if q_text.blank?

    a_el = q_el.at_css('[itemprop="acceptedAnswer"] [itemprop="text"]') ||
           q_el.at_css('[itemprop="acceptedAnswer"]')
    return nil unless a_el

    a_md = @extractor.node_to_markdown(a_el)
    return nil if a_md.blank?

    {
      question: q_text,
      answer: a_md,
      node: q_el,
      elements: [q_el]
    }
  end
end
