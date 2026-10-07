# Decides which links a website crawl may turn into documents. A crawl never leaves the site it started on.
# On the connected Shopify store it follows only content pages: products and collections come from the
# catalog sync and live tools, so crawled copies would add stale prices and stock to the knowledge base.
class Captain::Documents::CrawlScope
  STORE_CONTENT_PATH = '^/(?:[a-z]{2}(?:-[a-z]{2})?/)?(?:pages|policies|blogs)(?:/|$)'.freeze
  STORE_CONTENT_REGEX = Regexp.new(STORE_CONTENT_PATH, Regexp::IGNORECASE)

  def initialize(document)
    @host = host_of(document.external_link)
    @store = document.assistant.default_link_allowlist.any? { |base_url| host_of(base_url) == @host }
  end

  def follow?(link)
    host_of(link) == @host && (!@store || STORE_CONTENT_REGEX.match?(URI.parse(link).path))
  rescue URI::Error
    false
  end

  def firecrawl_include_paths
    @store ? [STORE_CONTENT_PATH] : []
  end

  private

  def host_of(url)
    URI.parse(url).host.to_s.downcase.delete_prefix('www.')
  end
end
