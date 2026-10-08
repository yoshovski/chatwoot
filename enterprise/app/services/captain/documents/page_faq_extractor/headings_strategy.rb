class Captain::Documents::PageFaqExtractor::HeadingsStrategy
  MIN_HEADINGS_COUNT = 3

  def initialize(extractor, node, doc)
    @extractor = extractor
    @node = node
    @doc = doc
  end

  def extract
    candidates = find_candidate_headings
    return [] if candidates.size < MIN_HEADINGS_COUNT

    candidate_set = candidates.to_set
    faqs = []
    candidates.each do |heading|
      next if @extractor.consumed?(heading)

      candidate = build_candidate(heading, candidate_set)
      next unless candidate

      claim_candidate(candidate)
      faqs << candidate
    end
    faqs
  end

  private

  def find_candidate_headings
    @node.css('h2, h3, h4').reject { |h| @extractor.consumed?(h) }.select do |h|
      h.text.strip.end_with?('?')
    end
  end

  def build_candidate(heading, candidate_set)
    q_text = heading.text.strip
    return nil if q_text.blank?

    siblings = collect_following_siblings(heading, candidate_set)
    a_md = render_siblings_markdown(siblings)
    return nil if a_md.blank?

    {
      question: q_text,
      answer: a_md,
      node: heading,
      elements: [heading] + siblings
    }
  end

  def collect_following_siblings(heading, candidate_set)
    level = heading.name[1].to_i
    siblings = []
    curr = heading.next_element
    while curr
      break if curr.name =~ /\Ah([1-#{level}])\z/ || candidate_set.include?(curr)

      siblings << curr unless @extractor.consumed?(curr)
      curr = curr.next_element
    end
    siblings
  end

  def render_siblings_markdown(siblings)
    container = Nokogiri::XML::Node.new('div', @doc)
    siblings.each { |s| container.add_child(s.dup) }
    @extractor.node_to_markdown(container)
  end

  def claim_candidate(candidate)
    candidate[:elements].each { |el| @extractor.consume!(el) }
  end
end
