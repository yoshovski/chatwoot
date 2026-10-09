class Captain::Tools::HtmlPageParser
  BASE_REMOVE_SELECTOR = ('script, style, noscript, template, svg, iframe, form, nav, header, footer, aside, ' \
    '[role="navigation"], [role="banner"], [role="contentinfo"]').freeze
  HIDDEN_SELECTOR = '[aria-hidden="true"], [hidden]'.freeze
  NOISE_PATTERN = /(?:\A|[^a-z0-9])(cookie|announcement|newsletter|popup|modal|drawer|breadcrumb)s?(?=[^a-z0-9]|\z)/i

  attr_reader :doc

  def initialize(html)
    @doc = Nokogiri::HTML(html)
  end

  def title
    @doc.at_xpath('//title')&.text&.strip
  end

  def faqs
    @faqs ||= faq_extractor.extract
  end

  def body_markdown
    node = main_content_node
    return '' unless node

    cleaned_node = clean_node(node.dup)
    markdown = ReverseMarkdown.convert(cleaned_node, unknown_tags: :bypass, github_flavored: true) || ''
    collapse_blank_lines(markdown)
  end

  def body_markdown_without_faqs
    node = main_content_node
    return '' unless node

    faqs

    faq_extractor.elements_to_remove.each do |el|
      el['data-cw-faq-matched'] = 'true' if el.respond_to?(:[]=)
    end

    dup_node = node.dup
    dup_node.css('[data-cw-faq-matched]').remove

    faq_extractor.elements_to_remove.each do |el|
      el.remove_attribute('data-cw-faq-matched') if el.respond_to?(:remove_attribute)
    end

    cleaned_node = clean_node(dup_node)
    markdown = ReverseMarkdown.convert(cleaned_node, unknown_tags: :bypass, github_flavored: true) || ''
    collapse_blank_lines(markdown)
  end

  private

  def faq_extractor
    @faq_extractor ||= begin
      node = main_content_node || @doc
      Captain::Documents::PageFaqExtractor.new(node, doc: @doc)
    end
  end

  def main_content_node
    return @doc.at_css('main') if @doc.at_css('main')
    return @doc.at_css('[role="main"]') if @doc.at_css('[role="main"]')

    articles = @doc.css('article')
    return articles.first if articles.size == 1

    @doc.at_css('body') || @doc
  end

  def clean_node(node)
    node.css(BASE_REMOVE_SELECTOR).remove
    clean_hidden_elements(node)
    node.css('[id], [class]').each do |element|
      element.remove if noise_element?(element)
    end
    node
  end

  def clean_hidden_elements(node)
    node.css(HIDDEN_SELECTOR).each do |element|
      element.remove unless preserve_hidden_element?(element)
    end
  end

  def preserve_hidden_element?(element)
    return true if element.ancestors('details').any?

    element_id = element['id']
    return true if element_id.present? && aria_controlled_ids.include?(element_id)

    element.ancestors.any? { |a| a['id'].present? && aria_controlled_ids.include?(a['id']) }
  end

  def aria_controlled_ids
    @aria_controlled_ids ||= @doc.css('[aria-controls]').filter_map { |el| el['aria-controls'] }.to_set
  end

  def noise_element?(element)
    noise_identifier?(element['id']) || noise_identifier?(element['class'])
  end

  def noise_identifier?(value)
    return false if value.blank?

    value.to_s.underscore.match?(NOISE_PATTERN)
  end

  def collapse_blank_lines(text)
    text.gsub(/(?:\r?\n[ \t]*){3,}(?:\r?\n|\z)/, "\n\n\n")
  end
end
