class Captain::Websites::DiscoveryService # rubocop:disable Metrics/ClassLength
  MAX_PAGES = 2000
  MAX_HTML_FETCHES = 500
  MAX_SITEMAPS = 40
  MAX_DURATION = 10.minutes
  # A run that stops at its fetch or time limit continues in another round, up to this many in a row.
  MAX_ROUNDS = 6
  # fresh starts over; continue reads what earlier rounds listed but never opened; refresh keeps
  # known pages and checks the site's sitemaps and start page again for new ones.
  MODES = %w[fresh continue refresh].freeze
  # Technical hosts, utility paths and query URLs are listed but never worth a request.
  UNFETCHED_REASONS = %w[technical_host utility query].freeze

  def initialize(source, mode: 'fresh')
    raise ArgumentError, "unknown discovery mode #{mode}" unless MODES.include?(mode)

    @source = source
    @mode = mode
    @previous_urls = source.pages.to_set { |page| page['url'] }
    @policy = Captain::Websites::UrlPolicy.new(source)
    @pages = {}
    @queue = Captain::Websites::SectionQueue.new
    @sitemaps = []
    @seen_sitemaps = Set.new
    @help_centers = []
    @seen_help_centers = Set.new
    @llms_indexes = []
    @seen_llms_indexes = Set.new
    @limits = Set.new
    @boilerplate = Captain::Websites::BoilerplateLearner.new
    @language = Captain::Websites::PageRules.locale(source.url)
    @stats = { 'fetched_pages' => 0, 'successful_pages' => 0, 'sitemaps' => 0, 'help_center_articles' => 0, 'errors' => 0,
               'limited' => false, 'limits' => [], 'phase' => 'sitemaps', 'run' => SecureRandom.hex(6), 'round' => round }
  end

  def perform
    @fetcher = Captain::Websites::PoliteFetcher.new(Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_DURATION)
    @robots = Captain::Websites::OriginRobots.new(@fetcher) { |sitemap| add_sitemap(sitemap) }
    @source.update!(status: 'discovering', error_code: nil, discovery_stats: @stats)
    queue_start_pages
    discover_map if Captain::Tools::FirecrawlService.configured?
    discover
    finish
  rescue StandardError => e
    # Discard unsaved page data so a serialization failure cannot also break this update.
    @source.reload.update!(status: 'failed', error_code: 'discovery_failed')
    Rails.logger.warn "[Captain][WebsiteDiscovery] source_id=#{@source.id} error=#{e.class.name}"
    raise
  end

  private

  def round = @mode == 'continue' ? @source.discovery_stats.to_h.fetch('round', 1) + 1 : 1

  # Earlier rounds' pages stay. A continued round skips what was already listed through help centres
  # and llms.txt; a refresh lists them again and re-reads the start page, where new pages show up first.
  def queue_start_pages
    seed_pages unless @mode == 'fresh'
    @robots.for(@source.url)
    add_page(@source.url, 'start')
    @source.selected_urls.each { |url| add_page(url, 'selected') }
  end

  def seed_pages
    @source.pages.each do |page|
      @pages[page['url']] = page.except('bucket', 'reason')
      @queue.push(page['url']) if unread?(page)
    end
    start = @pages[@source.url]
    @language ||= start&.dig('lang')
    @mode == 'continue' ? skip_listed_indexes : reread(start)
  end

  # The loop above already queued an unread page.
  def reread(page)
    @queue.push(page['url']) if page && !unread?(page)
  end

  def skip_listed_indexes
    @pages.each_value do |page|
      origin = URI.join(page['url'], '/').to_s.delete_suffix('/')
      @seen_llms_indexes << origin
      @seen_help_centers << origin if page['help_center_article_id']
    end
  end

  def unread?(page)
    !(page['fetched'] || page.key?('words') || page['checked'] || page['blocked_reason']) &&
      !Captain::Websites::PageRules.reason(page['url']).in?(UNFETCHED_REASONS)
  end

  def finish
    record_limits
    apply_robots
    success = found_pages?
    @stats.merge!(round_stats(success)).compact!
    persist(status: success ? 'ready' : 'failed', error_code: success ? nil : 'no_pages_found', discovered_at: Time.current)
    return unless success

    Captain::Websites::ClassifySectionsJob.perform_later(@source.id, @stats['run'])
    Captain::Websites::VerifyPagesJob.perform_later(@source.id, @stats['run'])
  end

  # A later round may open nothing new and still keep the pages earlier rounds found.
  def found_pages?
    @stats.values_at('successful_pages', 'sitemaps', 'help_center_articles').any?(&:positive?) || (@mode != 'fresh' && @pages.any?)
  end

  def round_stats(success)
    { 'phase' => 'done', 'classification' => ('pending' if success), 'verification' => ('pending' if success),
      'continue' => (true if success && continue?), 'new_urls' => new_urls.presence,
      'boilerplate' => @boilerplate.to_h, 'boilerplate_sections' => @boilerplate.sections }
  end

  def continue? = @stats['round'] < MAX_ROUNDS && @limits.intersect?(%w[requests time])

  # Pages no earlier run listed; a first discovery has nothing to compare with.
  def new_urls = @previous_urls.empty? ? [] : @pages.keys.reject { |url| @previous_urls.include?(url) }

  def record_limits
    @limits << 'time' unless @fetcher.before_deadline?
    @limits << 'origins' if @robots.limited?
    @limits << 'sitemaps' if @sitemaps.any?
    @limits << 'requests' if @stats['fetched_pages'] >= MAX_HTML_FETCHES && @queue.any? { |url| fetchable?(url) }
  end

  def discover
    while @fetcher.before_deadline?
      break unless discover_next

      persist if ((@stats['fetched_pages'] + @seen_sitemaps.size) % 10).zero?
    end
  end

  def discover_next
    if @help_centers.any?
      discover_help_center(@help_centers.shift)
    elsif @llms_indexes.any?
      discover_llms_index(@llms_indexes.shift)
    elsif @sitemaps.any? && @seen_sitemaps.size < MAX_SITEMAPS
      discover_sitemap(@sitemaps.shift)
    elsif (url = next_page)
      discover_page(url)
    else
      return false
    end
    true
  end

  def next_page
    return if @stats['fetched_pages'] >= MAX_HTML_FETCHES

    @stats['phase'] = 'pages'
    @queue.shift { |url| fetchable?(url) }
  end

  # Other-language copies, and articles already read from a help-centre API, need no fetch.
  def fetchable?(url)
    locale = Captain::Websites::PageRules.locale(url)
    @pages[url]['help_center_article_id'].nil? && (locale.nil? || @language.nil? || locale == @language)
  end

  def discover_map
    response = Captain::Tools::FirecrawlService.new.map(@source.url, include_subdomains: @source.include_subdomains?, limit: MAX_PAGES)
    return @stats['map_failed'] = true unless response.success?

    links = response.parsed_response.fetch('links', [])
    @limits << 'pages' if links.size >= MAX_PAGES
    links.each { |link| add_page(link.fetch('url'), 'map') }
  rescue Net::ReadTimeout, Net::OpenTimeout, SocketError, HTTParty::Error
    @stats['map_failed'] = true
  end

  def add_page(value, from, base: nil, attributes: {})
    url = Captain::Websites::UrlPolicy.normalize(value, base: base)
    return unless url && @policy.within_scope?(url) && @policy.page?(url)
    return @pages[url].merge!(attributes) if @pages.key?(url)
    return @limits << 'pages' if @pages.size >= MAX_PAGES

    @pages[url] = { 'url' => url, 'title' => nil, 'discovered_from' => from, 'blocked_reason' => @policy.blocked_reason(url) }.merge(attributes)
    queue(url)
  end

  def queue(url)
    origin = URI.join(url, '/').to_s.delete_suffix('/')
    @help_centers << origin if Captain::Websites::HelpCenter.candidate?(url) && @seen_help_centers.add?(origin)
    return if @pages[url]['blocked_reason'] || Captain::Websites::PageRules.reason(url).in?(UNFETCHED_REASONS)

    @queue.push(url)
    @llms_indexes << origin if @seen_llms_indexes.add?(origin)
  end

  def discover_help_center(origin)
    @stats['phase'] = 'help_center'
    robots = @robots.for(origin)
    return unless robots

    fetcher = ->(url) { @fetcher.fetch(url, robots.delay)&.first if robots.allowed?(url) }
    Captain::Websites::HelpCenter.new(origin, fetcher).each_article(MAX_PAGES - @pages.size) do |page|
      @stats['help_center_articles'] += 1
      add_page(page.delete('url'), 'help_center', attributes: page)
    end
  end

  def discover_llms_index(origin)
    robots = @robots.for(origin)
    text, = @fetcher.fetch("#{origin}/llms.txt", robots.delay) if robots&.allowed?("#{origin}/llms.txt")
    Captain::Websites::LlmsIndex.pages(text, origin).each { |page| add_page(page.delete('url'), 'llms', attributes: page) }
  end

  def discover_page(url)
    robots = @robots.for(url)
    # Past the origin limit robots.txt is unknown: leave the page unchecked rather than blocked.
    return unless robots
    return @pages[url]['blocked_reason'] = 'robots_disallowed' unless robots.allowed?(url)

    @stats['fetched_pages'] += 1
    @pages[url]['fetched'] = true
    html, content_type = @fetcher.fetch(url, robots.delay)
    return unless html

    @stats['successful_pages'] += 1
    if content_type.nil? || content_type.include?('html')
      read_page(url, html)
    else
      @pages[url]['not_html'] = true
    end
  end

  def read_page(url, html)
    signals = Captain::Websites::PageSignals.new(html, url)
    @pages[url].merge!(signals.to_h)
    @boilerplate.add(url, signals.block_hashes)
    @language ||= @pages[url]['lang'] if url == @source.url
    signals.links.each { |link| add_page(link, 'link', base: url) }
  end

  def discover_sitemap(url)
    @stats['phase'] = 'sitemaps'
    return unless @seen_sitemaps.add?(url)

    robots = @robots.for(url)
    return unless robots&.allowed?(url)

    text, = @fetcher.fetch(url, robots.delay)
    process_sitemap(text) if text
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
    return unless url && @policy.within_scope?(url) && !Captain::Websites::PageRules.technical_host?(URI.parse(url).host)
    return if @seen_sitemaps.include?(url) || @sitemaps.include?(url)
    return @limits << 'sitemaps' if @sitemaps.size >= MAX_SITEMAPS

    @sitemaps << url
  end

  # Sitemap, map and help-centre pages are never fetched one by one; check them against
  # every robots.txt read during this run.
  def apply_robots
    @pages.each_value { |page| page['blocked_reason'] ||= ('robots_disallowed' if @robots.disallowed?(page['url'])) }
  end

  def persist(**attributes)
    @stats.merge!('limits' => @limits.to_a, 'limited' => @limits.any?, 'errors' => @fetcher.errors)
    pages = Captain::Websites::PageBuckets.new(@source).perform(@pages.values)
    @source.update!(pages: pages, discovery_stats: @stats, **attributes)
  end
end
