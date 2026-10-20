# Zendesk Guide help centres (/hc/ paths) publish their articles through a public API.
# It lists every published article with its section and returns clean article bodies,
# which crawling HTML misses or wraps in navigation.
class Captain::Websites::HelpCenter
  MAX_BYTES = 5.megabytes
  PER_PAGE = 100

  def self.candidate?(url) = URI.parse(url).path.start_with?('/hc/')

  def initialize(origin, fetcher)
    @origin = origin
    @fetcher = fetcher
  end

  # Yields each published article in the help centre's default locale as a page hash.
  def each_article(limit)
    locale = get('/api/v2/help_center/locales.json')&.fetch('default_locale', nil)
    return unless locale

    sections = {}
    paginate("/api/v2/help_center/#{locale}/sections.json", 'sections') { |section| sections[section['id']] = section['name'] }
    count = 0
    paginate("/api/v2/help_center/#{locale}/articles.json", 'articles') do |article|
      return if count >= limit

      count += 1
      yield page(article, sections)
    end
  end

  def self.article(origin, article_id)
    data = JSON.parse(read("#{origin}/api/v2/help_center/articles/#{Integer(article_id)}.json")).fetch('article')
    parser = Captain::Tools::HtmlPageParser.new("<html><body><main>#{data['body']}</main></body></html>")
    { title: data['title'], content: parser.body_markdown_without_faqs, faqs: parser.faqs }
  end

  def self.read(url)
    SafeFetch.fetch(url, validate_content_type: false, max_bytes: MAX_BYTES, read_timeout: 10,
                         headers: { 'User-Agent' => "#{Captain::Websites::RobotsPolicy::AGENT}/1.0", 'Accept' => 'application/json' }) do |result|
      result.tempfile.read
    end
  end

  private

  def get(url)
    url = "#{@origin}#{url}" if url.start_with?('/')
    return unless url.start_with?("#{@origin}/")

    text = @fetcher.call(url)
    JSON.parse(text) if text
  rescue JSON::ParserError
    nil
  end

  def paginate(path, key, &)
    url = "#{@origin}#{path}?per_page=#{PER_PAGE}"
    while url
      data = get(url) || return
      data.fetch(key, []).each(&)
      url = data['next_page']
    end
  end

  def page(article, sections)
    text = Nokogiri::HTML.fragment(article['body'].to_s).text
    host = URI.parse(@origin).host.delete_prefix('www.')
    {
      'url' => article['html_url'],
      'title' => article['title'].to_s.first(255).presence,
      'help_center_article_id' => article['id'],
      'section' => "#{host}/#{sections[article['section_id']] || 'articles'}",
      'words' => text.split.size,
      'fingerprint' => Digest::SHA256.hexdigest(text.gsub(/\s+/, ' ').strip).first(16),
      'updated_at' => article['updated_at']
    }
  end
end
