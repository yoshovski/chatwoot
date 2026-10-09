class Captain::Documents::PageFaqExtractor::DlStrategy
  def initialize(extractor, node, doc)
    @extractor = extractor
    @node = node
    @doc = doc
  end

  def extract
    faqs = []
    @node.css('dl').each do |dl_node|
      next if @extractor.consumed?(dl_node)

      extract_from_dl(dl_node, faqs)
    end
    faqs
  end

  private

  def extract_from_dl(dl_node, faqs)
    dt_elements = dl_node.css('dt').reject { |element| @extractor.consumed?(element) }
    question_dts = dt_elements.select { |element| element.text.strip.end_with?('?') }
    return if question_dts.size < 2

    dt_elements.each do |dt_node|
      candidate = build_candidate(dt_node)
      next unless candidate

      claim_candidate(candidate)
      faqs << candidate
    end
  end

  def build_candidate(dt_node)
    q_text = dt_node.text.strip
    return nil if q_text.blank?

    dd_siblings = collect_dd_siblings(dt_node)
    return nil if dd_siblings.empty?

    a_md = render_dd_markdown(dd_siblings)
    return nil if a_md.blank?

    {
      question: q_text,
      answer: a_md,
      node: dt_node,
      elements: [dt_node] + dd_siblings
    }
  end

  def collect_dd_siblings(dt_node)
    dd_siblings = []
    curr = dt_node.next_element
    while curr && curr.name == 'dd'
      dd_siblings << curr unless @extractor.consumed?(curr)
      curr = curr.next_element
    end
    dd_siblings
  end

  def render_dd_markdown(dd_siblings)
    container = Nokogiri::XML::Node.new('div', @doc)
    dd_siblings.each { |dd| container.add_child(dd.dup) }
    @extractor.node_to_markdown(container)
  end

  def claim_candidate(candidate)
    candidate[:elements].each { |el| @extractor.consume!(el) }
  end
end
