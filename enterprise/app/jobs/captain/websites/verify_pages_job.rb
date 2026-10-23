# After discovery, checks pages that were listed (from sitemaps, maps or links) but never
# opened, so missing or sign-in-only pages are excluded before anyone selects them. The first
# pages of every section are read in full, so a section can be recommended from measured text.
class Captain::Websites::VerifyPagesJob < ApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  MAX_PAGES = 1000
  MAX_READ_PAGES = 150
  MAX_DURATION = 10.minutes
  MISSING = [404, 410].freeze
  SIGN_IN = [401, 403].freeze

  # run identifies the discovery that requested the check; a newer discovery makes it stale.
  def perform(source_id, run)
    source = Captain::WebsiteSource.find(source_id)
    return unless current?(source, run)

    results = check(unchecked_urls(source))
    finished = source.with_lock do
      next unless current?(source, run)

      source.discovery_stats = source.discovery_stats.merge('verification' => 'done', 'verified_pages' => results.size)
      pages = source.pages.map { |page| results.key?(page['url']) ? page.merge(results[page['url']]) : page }
      source.update!(pages: Captain::Websites::PageBuckets.new(source).perform(pages))
      Captain::Websites::RoundFinisher.claim?(source)
    end
    Captain::Websites::RoundFinisher.new(source).perform if finished
  end

  private

  def current?(source, run) = source.status == 'ready' && source.discovery_stats['run'] == run

  # Round-robin over sections, so every section gets its first pages read before a large one uses the budget.
  def unchecked_urls(source)
    pages = source.pages.select do |page|
      page['bucket'] != 'excluded' && !page.key?('words') && !page['checked'] && page['help_center_article_id'].nil?
    end
    sections = pages.group_by { |page| page['section'] }.values
    sections.first.zip(*sections.drop(1)).flatten.compact.first(MAX_PAGES).pluck('url') if sections.any?
  end

  def check(urls)
    fetcher = Captain::Websites::PoliteFetcher.new(Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_DURATION)
    robots = Captain::Websites::OriginRobots.new(fetcher) { nil }
    Array(urls).each_with_index.with_object({}) do |(url, index), results|
      break results unless fetcher.before_deadline?

      policy = robots.for(url)
      next unless policy&.allowed?(url)

      result = index < MAX_READ_PAGES ? read(fetcher, url, policy.delay) : probe(fetcher, url, policy.delay)
      results[url] = result if result
    end
  end

  def read(fetcher, url, delay)
    status, html, content_type = fetcher.read_paced(url, delay)
    return outcome(status) if status && status != 200
    return unless html

    return { 'not_html' => true } unless content_type.nil? || content_type.include?('html')

    Captain::Websites::PageSignals.new(html, url).to_h.merge('checked' => true)
  end

  def probe(fetcher, url, delay)
    status = fetcher.probe(url, delay)
    outcome(status) if status
  end

  def outcome(status)
    return { 'missing' => true } if MISSING.include?(status)
    return { 'login' => true } if SIGN_IN.include?(status)

    { 'checked' => true }
  end
end
