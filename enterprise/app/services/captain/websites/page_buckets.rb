# Sorts discovered pages into recommended, maybe and excluded, each exclusion with a reason.
# Section labels from Captain::Websites::SectionClassifier refine the URL and content rules.
class Captain::Websites::PageBuckets
  THIN_WORDS = 60
  # Page flags from discovery and verification, and the exclusion reason each one gives.
  FLAGS = { 'missing' => 'not_found', 'not_html' => 'not_html', 'noindex' => 'noindex', 'login' => 'login', 'listing' => 'listing' }.freeze

  def initialize(source)
    @source = source
    @labels = source.discovery_stats.to_h['sections'] || {}
    @page_labels = source.discovery_stats.to_h['page_labels'] || {}
    @start_host = URI.parse(source.url).host.delete_prefix('www.')
  end

  def perform(pages)
    @urls = pages.to_set { |page| page['url'] }
    @originals = original_urls(pages)
    @near_copies = near_copies(pages)
    @language = primary_language(pages)
    pages.map do |page|
      page = page.merge('section' => page['section'] || Captain::Websites::PageRules.section(page['url']))
      reason = exclusion(page)
      page.merge('bucket' => reason ? 'excluded' : bucket(page), 'reason' => reason).compact
    end
  end

  private

  def exclusion(page)
    page['blocked_reason'] || Captain::Websites::PageRules.reason(page['url']) || content_reason(page) || language_reason(page) ||
      ('not_useful' if label_for(page)&.dig('label') == 'not_useful')
  end

  # A page labelled on its own (a one-page section) wins over its section's label.
  def label_for(page) = @page_labels[page['url']] || @labels[page['section']]

  def content_reason(page)
    page['import_issue'] || FLAGS.find { |key, _| page[key] }&.last || measured_reason(page)
  end

  def measured_reason(page)
    return 'duplicate' if duplicate?(page)

    'thin' if page.fetch('words', THIN_WORDS) < THIN_WORDS
  end

  # A canonical link to another discovered page, or the same or nearly the same text as a shorter URL.
  def duplicate?(page)
    @urls.include?(page['canonical']) || @originals.fetch(page['fingerprint'], page['url']) != page['url'] ||
      @near_copies.include?(page['url'])
  end

  # One page per fingerprint stays: a canonical target first, then HTTPS, then the shortest path.
  def original_urls(pages)
    pages.reject { |page| page['fingerprint'].nil? }.group_by { |page| page['fingerprint'] }.transform_values do |copies|
      copies.min_by { |page| keep_rank(page, canonical_targets(pages)) }['url']
    end
  end

  # Pages whose text nearly matches a page kept before them in the same keep order.
  def near_copies(pages)
    kept = Captain::Knowledge::MinHash::Index.new
    pages.select { |page| page['minhash'] }.sort_by { |page| keep_rank(page, canonical_targets(pages)) }
         .each_with_object(Set.new) do |page, copies|
      kept.near?(page['minhash']) ? copies << page['url'] : kept.add(page['minhash'])
    end
  end

  def canonical_targets(pages) = @canonical_targets ||= pages.filter_map { |page| page['canonical'] }.to_set

  def keep_rank(page, targets)
    uri = URI.parse(page['url'])
    [targets.include?(page['url']) ? 0 : 1, uri.scheme == 'https' ? 0 : 1, uri.path.count('/'), page['url'].length, page['url']]
  end

  def language_reason(page)
    language = Captain::Websites::PageRules.locale(page['url']) || page['lang']
    'other_language' if @language && language && language != @language
  end

  def bucket(page)
    # Only pages whose text was read can be recommended; the rest wait for the administrator.
    return 'maybe' unless page['words']

    label = label_for(page)
    return label['recommended'] ? 'recommended' : 'maybe' if label

    host = URI.parse(page['url']).host.delete_prefix('www.')
    recommended = host == @start_host || page['discovered_from'] == 'help_center' || Captain::Websites::PageRules.support_host?(host)
    recommended ? 'recommended' : 'maybe'
  end

  def primary_language(pages)
    start = pages.find { |page| page['url'] == @source.url }
    start&.dig('lang') || Captain::Websites::PageRules.locale(@source.url)
  end
end
