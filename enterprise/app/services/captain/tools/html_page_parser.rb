class Captain::Tools::HtmlPageParser
  REMOVE_SELECTOR = ('script, style, noscript, template, svg, iframe, form, nav, header, footer, aside, ' \
    '[role="navigation"], [role="banner"], [role="contentinfo"], [aria-hidden="true"], [hidden]').freeze
  NOISE_PATTERN = /(?:\A|[^a-z0-9])(cookie|announcement|newsletter|popup|modal|drawer|breadcrumb)s?(?=[^a-z0-9]|\z)/i

  attr_reader :doc

  def initialize(html)
    @doc = Nokogiri::HTML(html)
  end

  def title
    @doc.at_xpath('//title')&.text&.strip
  end

  def body_markdown
    node = main_content_node
    return '' unless node

    cleaned_node = clean_node(node.dup)
    markdown = ReverseMarkdown.convert(cleaned_node, unknown_tags: :bypass, github_flavored: true) || ''
    collapse_blank_lines(markdown)
  end

  private

  def main_content_node
    return @doc.at_css('main') if @doc.at_css('main')
    return @doc.at_css('[role="main"]') if @doc.at_css('[role="main"]')

    articles = @doc.css('article')
    return articles.first if articles.size == 1

    @doc.at_css('body') || @doc
  end

  def clean_node(node)
    node.css(REMOVE_SELECTOR).remove
    node.css('[id], [class]').each do |element|
      element.remove if noise_element?(element)
    end
    node
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
