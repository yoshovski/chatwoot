# Decides whether a website document also adds the pages it links to, and which ones. By default a page on the
# connected Shopify store is added alone and other sites follow their links. A crawl never leaves the site it
# started on, and on the store it follows only content pages: products and collections come from the catalog
# sync and live tools, so crawled copies would add stale prices and stock to the knowledge base.
class Captain::Documents::CrawlScope
  STORE_CONTENT_PATH = '^/(?:[a-z]{2}(?:-[a-z]{2})?/)?(?:pages|policies|blogs)(?:/|$)'.freeze
  STORE_CONTENT_REGEX = Regexp.new(STORE_CONTENT_PATH, Regexp::IGNORECASE)

  def initialize(document)
    @document = document
    @host = host_of(document.external_link)
    @store = document.assistant.default_link_allowlist.any? { |base_url| host_of(base_url) == @host }
  end

  def follow_links?
    choice = @document.include_linked_pages
    choice.nil? ? !@store : ActiveModel::Type::Boolean.new.cast(choice)
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
