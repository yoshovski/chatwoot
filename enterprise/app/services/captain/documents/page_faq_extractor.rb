class Captain::Documents::PageFaqExtractor
  MAX_QUESTION_LENGTH = 300
  MIN_QUESTION_LENGTH = 5
  MAX_ANSWER_LENGTH = 5_000
  MAX_FAQS_COUNT = 200

  attr_reader :elements_to_remove

  def self.extract(node, doc: nil)
    new(node, doc: doc).extract
  end

  def initialize(node, doc: nil)
    @node = node
    @doc = doc || node.document || node
    @consumed_elements = Set.new
    @elements_to_remove = []
    @node_order = build_node_order(@doc)
  end

  def extract
    candidates = collect_candidates
    sorted_candidates = candidates.sort_by { |c| @node_order[c[:node]] || 0 }
    filter_and_dedupe(sorted_candidates)
  end

  def consumed?(element)
    return true if @consumed_elements.include?(element)

    element.ancestors.any? { |a| @consumed_elements.include?(a) }
  end

  def consume!(element)
    @consumed_elements.add(element)
    element.traverse { |child| @consumed_elements.add(child) if child.element? }
  end

  def html_to_markdown(html)
    return '' if html.blank?

    doc = Nokogiri::HTML.fragment(html)
    doc.css('script, style, noscript').remove
    md = ReverseMarkdown.convert(doc, unknown_tags: :bypass, github_flavored: true) || ''
    collapse_blank_lines(md).strip
  end

  def node_to_markdown(node)
    return '' unless node

    node_copy = node.dup
    node_copy.css('script, style, noscript').remove
    md = ReverseMarkdown.convert(node_copy, unknown_tags: :bypass, github_flavored: true) || ''
    collapse_blank_lines(md).strip
  end

  private

  def collect_candidates
    [
      JsonLdStrategy.new(self, @doc).extract,
      MicrodataStrategy.new(self, @node).extract,
      DetailsStrategy.new(self, @node).extract,
      AriaStrategy.new(self, @node, @doc).extract,
      DlStrategy.new(self, @node, @doc).extract,
      HeadingsStrategy.new(self, @node, @doc).extract
    ].flatten
  end

  def filter_and_dedupe(candidates)
    seen_questions = Set.new
    results = []

    candidates.each do |cand|
      faq = process_candidate(cand, seen_questions)
      next unless faq

      results << faq
      break if results.size >= MAX_FAQS_COUNT
    end

    results
  end

  def process_candidate(cand, seen_questions)
    question = cand[:question].to_s.strip
    answer = cand[:answer].to_s.strip[0...MAX_ANSWER_LENGTH]

    return nil unless valid_pair?(question, answer)

    track_removal_elements(cand[:elements])

    norm = normalize_question(question)
    return nil if seen_questions.include?(norm)

    seen_questions.add(norm)
    { 'question' => question, 'answer' => answer }
  end

  def valid_pair?(question, answer)
    question.length.between?(MIN_QUESTION_LENGTH, MAX_QUESTION_LENGTH) && answer.present?
  end

  def track_removal_elements(elements)
    Array(elements).each do |el|
      @elements_to_remove << el if el.present?
    end
  end

  def normalize_question(question_text)
    question_text.to_s.downcase.gsub(/\s+/, ' ').strip.sub(/\?+\z/, '').strip
  end

  def build_node_order(doc)
    order = {}
    idx = 0
    doc.traverse do |n|
      if n.element?
        order[n] = idx
        idx += 1
      end
    end
    order
  end

  def collapse_blank_lines(text)
    text.gsub(/(?:\r?\n[ \t]*){3,}(?:\r?\n|\z)/, "\n\n\n")
  end
end
