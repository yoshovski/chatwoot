require 'zlib'
require 'stringio'

class Captain::Websites::DiscoveryService
  MAX_PAGES = 2000
  MAX_HTML_FETCHES = 500
  MAX_SITEMAPS = 40
  MAX_ORIGINS = 16
  MAX_DURATION = 10.minutes
  MAX_BYTES = 5.megabytes

  def initialize(source)
    @source = source
    @policy = Captain::Websites::UrlPolicy.new(source)
    @pages = {}
    @queue = []
    @sitemaps = []
    @seen_sitemaps = Set.new
    @robots = {}
    @last_requests = {}
    @stats = { 'fetched_pages' => 0, 'successful_pages' => 0, 'sitemaps' => 0, 'errors' => 0, 'limited' => false }
  end

  def perform
    @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_DURATION
    @source.update!(status: 'discovering', error_code: nil, discovery_stats: @stats)
    robots_for(@source.url)
    add_page(@source.url, 'start')
    @source.selected_urls.each { |url| add_page(url, 'selected') }
    discover_map if Captain::Tools::FirecrawlService.configured?
    discover
    finish
  rescue StandardError => e
    @source.update!(status: 'failed', error_code: 'discovery_failed')
    Rails.logger.warn "[Captain][WebsiteDiscovery] source_id=#{@source.id} error=#{e.class.name}"
    raise
  end

  private

  def finish
    @stats['limited'] ||= @queue.any? || @sitemaps.any?
    success = @stats['successful_pages'].positive? || @stats['sitemaps'].positive?
    persist(status: success ? 'ready' : 'failed', error_code: success ? nil : 'no_pages_found', discovered_at: Time.current)
  end

  def discover
    while before_deadline?
      break unless discover_next

      persist if ((@stats['fetched_pages'] + @seen_sitemaps.size) % 10).zero?
    end
  end

  def discover_next
    if @sitemaps.any? && @seen_sitemaps.size < MAX_SITEMAPS
      discover_sitemap(@sitemaps.shift)
    elsif @queue.any? && @stats['fetched_pages'] < MAX_HTML_FETCHES
      discover_page(@queue.shift)
    else
      return false
    end
    true
  end

  def before_deadline?
    Process.clock_gettime(Process::CLOCK_MONOTONIC) < @deadline
  end

  def discover_map
    response = Captain::Tools::FirecrawlService.new.map(@source.url, include_subdomains: @source.include_subdomains?, limit: MAX_PAGES)
    unless response.success?
      @stats['errors'] += 1
      return
    end
    links = response.parsed_response.fetch('links', [])
    @stats['limited'] = true if links.size >= MAX_PAGES
    links.each { |link| add_page(link.fetch('url'), 'map') }
  rescue Net::ReadTimeout, Net::OpenTimeout, SocketError, HTTParty::Error
    @stats['errors'] += 1
  end

  def add_page(value, from, base: nil)
    url = Captain::Websites::UrlPolicy.normalize(value, base: base)
    return unless url && @policy.within_scope?(url) && @policy.page?(url)
    return if @pages.key?(url)

    if @pages.size >= MAX_PAGES
      @stats['limited'] = true
      return
    end

    @pages[url] = { 'url' => url, 'title' => nil, 'discovered_from' => from, 'blocked_reason' => @policy.blocked_reason(url) }
    @queue << url unless @pages[url]['blocked_reason']
  end

  def discover_page(url)
    robots = robots_for(url)
    unless robots&.allowed?(url)
      @pages[url]['blocked_reason'] = 'robots_disallowed'
      return
    end
    @stats['fetched_pages'] += 1
    html = fetch(url)
    return unless html

    @stats['successful_pages'] += 1
    doc = Nokogiri::HTML(html)
    @pages[url]['title'] = doc.at_css('title')&.text.to_s.strip.first(255).presence
    doc.css('a[href]').each { |link| add_page(link['href'], 'link', base: url) }
  end

  def discover_sitemap(url)
    return if @seen_sitemaps.include?(url)

    @seen_sitemaps << url
    return unless robots_for(url)&.allowed?(url)

    text = fetch(url)
    return unless text

    process_sitemap(text)
  end

  def process_sitemap(text)
    doc = Nokogiri::XML(text, &:nonet)
    case doc.root&.name
    when 'sitemapindex'
      sitemap_locations(doc, 'sitemap').each { |url| add_sitemap(url) }
    when 'urlset'
      @stats['sitemaps'] += 1
      sitemap_locations(doc, 'url').each { |url| add_page(url, 'sitemap') }
    end
  end

  def sitemap_locations(doc, kind)
    doc.xpath("//*[local-name()='#{kind}']/*[local-name()='loc']").map { |node| node.text.strip }
  end

  def add_sitemap(value)
    url = Captain::Websites::UrlPolicy.normalize(value)
    return unless url && @policy.within_scope?(url)
    return if @seen_sitemaps.include?(url) || @sitemaps.include?(url)
    return if @sitemaps.size >= MAX_SITEMAPS

    @sitemaps << url
  end

  def robots_for(url)
    origin = URI.join(url, '/').to_s.delete_suffix('/')
    return @robots[origin] if @robots.key?(origin)

    if @robots.size >= MAX_ORIGINS
      @stats['limited'] = true
      return
    end

    # Register before fetching so sitemaps referring to this origin cannot recurse.
    @robots[origin] = nil
    status, text = read("#{origin}/robots.txt")
    denied = status.nil? || status.in?([401, 403, 429]) || status >= 500
    policy = Captain::Websites::RobotsPolicy.new(text.to_s, denied: denied)
    @robots[origin] = policy
    policy.sitemaps.each { |sitemap| add_sitemap(sitemap) }
    add_sitemap("#{origin}/sitemap.xml")
    add_sitemap("#{origin}/sitemap_index.xml") if policy.sitemaps.empty?
    policy
  end

  def fetch(url)
    origin = URI.join(url, '/').to_s.delete_suffix('/')
    delay = @robots[origin]&.delay || 0.25
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    wait = delay - (now - @last_requests.fetch(origin, 0))
    sleep(wait) if wait.positive?
    return unless before_deadline?

    status, text = read(url)
    @last_requests[origin] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    text if status == 200
  end

  def read(url)
    body = SafeFetch.fetch(url, validate_content_type: false, max_bytes: MAX_BYTES, read_timeout: 10,
                                headers: { 'User-Agent' => "#{Captain::Websites::RobotsPolicy::AGENT}/1.0" }) { |result| result.tempfile.read }
    [200, decompress(body)]
  rescue SafeFetch::HttpError => e
    @stats['errors'] += 1
    [e.message.to_i, nil]
  rescue SafeFetch::Error
    @stats['errors'] += 1
    [nil, nil]
  end

  def decompress(body)
    return body unless body.start_with?("\x1F\x8B".b)

    text = Zlib::GzipReader.wrap(StringIO.new(body)) { |reader| reader.read(MAX_BYTES + 1) }
    raise SafeFetch::FileTooLargeError if text.bytesize > MAX_BYTES

    text
  rescue Zlib::Error
    raise SafeFetch::FetchError
  end

  def persist(**attributes)
    @source.update!(pages: @pages.values, discovery_stats: @stats, **attributes)
  end
end
