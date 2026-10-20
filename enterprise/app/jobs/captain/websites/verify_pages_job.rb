# After discovery, checks pages that were listed (from sitemaps, maps or links) but never
# opened, so missing or sign-in-only pages are excluded before anyone selects them.
class Captain::Websites::VerifyPagesJob < ApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  MAX_PAGES = 1000
  MAX_DURATION = 10.minutes
  MISSING = [404, 410].freeze
  SIGN_IN = [401, 403].freeze

  # run identifies the discovery that requested the check; a newer discovery makes it stale.
  def perform(source_id, run)
    source = Captain::WebsiteSource.find(source_id)
    return unless current?(source, run)

    results = check(unchecked_urls(source))
    source.with_lock do
      next unless current?(source, run)

      source.discovery_stats = source.discovery_stats.merge('verification' => 'done', 'verified_pages' => results.size)
      pages = source.pages.map { |page| results.key?(page['url']) ? page.merge(results[page['url']]) : page }
      source.update!(pages: Captain::Websites::PageBuckets.new(source).perform(pages))
    end
  end

  private

  def current?(source, run) = source.status == 'ready' && source.discovery_stats['run'] == run

  def unchecked_urls(source)
    source.pages.select do |page|
      page['bucket'] != 'excluded' && !page.key?('words') && !page['checked'] && page['help_center_article_id'].nil?
    end.first(MAX_PAGES).pluck('url')
  end

  def check(urls)
    fetcher = Captain::Websites::PoliteFetcher.new(Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_DURATION)
    robots = Captain::Websites::OriginRobots.new(fetcher) { nil }
    urls.each_with_object({}) do |url, results|
      break results unless fetcher.before_deadline?

      policy = robots.for(url)
      next unless policy&.allowed?(url)

      status = fetcher.probe(url, policy.delay)
      results[url] = outcome(status) if status
    end
  end

  def outcome(status)
    return { 'missing' => true } if MISSING.include?(status)
    return { 'login' => true } if SIGN_IN.include?(status)

    { 'checked' => true }
  end
end
