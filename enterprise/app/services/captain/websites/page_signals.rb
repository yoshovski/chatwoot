# Quality signals from one fetched HTML page, measured on the same main content the
# import keeps (navigation, headers and footers removed).
class Captain::Websites::PageSignals
  DESCRIPTION_LENGTH = 200
  LINK = /!?\[([^\]]*)\]\([^)]*\)/

  def initialize(html, url)
    @url = url
    @parser = Captain::Tools::HtmlPageParser.new(html)
    @doc = @parser.doc
  end

  def to_h
    head.merge(content).reject { |_, value| value.nil? || value == false }
  end

  def links = @doc.css('a[href]').pluck('href')
  def block_hashes = Captain::Knowledge::PageCleaner.block_hashes(markdown)

  private

  def markdown = @markdown ||= @parser.body_markdown_without_faqs

  def head
    {
      'title' => @parser.title.to_s.strip.first(255).presence,
      'description' => meta('description')&.first(DESCRIPTION_LENGTH),
      'lang' => @doc.at_css('html')&.[]('lang').to_s[/\A[a-z]{2}/i]&.downcase,
      'canonical' => canonical,
      'noindex' => meta('robots').to_s.match?(/noindex/i),
      'schema' => schema_types.presence
    }
  end

  def content
    text = markdown.gsub(LINK, '\1')
    words = text.split.size
    link_words = markdown.scan(LINK).sum { |(label)| label.split.size }
    {
      'words' => words,
      'login' => @parser.login_form? && words < 300,
      # Index pages are mostly links: category, section and archive listings.
      'listing' => words.between?(1, 600) && link_words.fdiv(words) > 0.6,
      'fingerprint' => (Digest::SHA256.hexdigest(text.gsub(/\s+/, ' ').strip).first(16) if words.positive?),
      'minhash' => Captain::Knowledge::MinHash.of(text)
    }
  end

  def meta(name)
    @doc.css('meta[name]').find { |node| node['name'].casecmp?(name) }&.[]('content').to_s.strip.presence
  end

  def canonical
    href = @doc.at_css('link[rel="canonical"]')&.[]('href')
    url = Captain::Websites::UrlPolicy.normalize(href, base: @url) if href
    url unless url == @url
  end

  def schema_types
    @doc.css('script[type="application/ld+json"]').flat_map do |script|
      Array.wrap(JSON.parse(script.text)).filter_map { |item| item['@type'] if item.is_a?(Hash) }
    rescue JSON::ParserError
      []
    end.flatten.uniq.first(5)
  end
end
