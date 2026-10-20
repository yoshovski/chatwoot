# Sorts discovered pages into recommended, maybe and excluded, each exclusion with a reason.
# Section labels from Captain::Websites::SectionClassifier refine the URL and content rules.
class Captain::Websites::PageBuckets
  THIN_WORDS = 60

  def initialize(source)
    @source = source
    @labels = source.discovery_stats.to_h['sections'] || {}
    @start_host = URI.parse(source.url).host.delete_prefix('www.')
  end

  def perform(pages)
    @urls = pages.to_set { |page| page['url'] }
    @originals = original_urls(pages)
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
      ('not_useful' if @labels.dig(page['section'], 'label') == 'not_useful')
  end

  def content_reason(page)
    flag = %w[not_html noindex login].find { |key| page[key] }
    return flag if flag
    return 'duplicate' if duplicate?(page)
    return 'listing' if page['listing']

    'thin' if page['words'] && page['words'] < THIN_WORDS
  end

  # A canonical link to another discovered page, or the same text as a shorter URL.
  def duplicate?(page)
    @urls.include?(page['canonical']) || @originals.fetch(page['fingerprint'], page['url']) != page['url']
  end

  def original_urls(pages)
    pages.reject { |page| page['fingerprint'].nil? }.sort_by { |page| page['url'].length }
         .each_with_object({}) { |page, result| result[page['fingerprint']] ||= page['url'] }
  end

  def language_reason(page)
    language = Captain::Websites::PageRules.locale(page['url']) || page['lang']
    'other_language' if @language && language && language != @language
  end

  def bucket(page)
    label = @labels[page['section']]
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
