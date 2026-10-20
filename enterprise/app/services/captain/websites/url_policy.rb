require 'addressable/uri'
require 'public_suffix'

class Captain::Websites::UrlPolicy
  NON_PAGE_EXTENSIONS = /\.(?:avif|bmp|css|docx?|eot|gif|ico|jpe?g|js|json|map|mp[34]|ogg|pdf|png|pptx?|svg|ttf|web[mp]|woff2?|xlsx?|zip)\z/i

  def self.normalize(value, base: nil)
    return unless value.is_a?(String) && value.length <= 2048

    uri = base ? Addressable::URI.join(base, value) : Addressable::URI.parse(value)
    return unless valid_uri?(uri)

    strip_tracking(uri)
    uri.normalize.to_s.delete_suffix('/')
  rescue Addressable::URI::InvalidURIError, URI::InvalidURIError, TypeError, ArgumentError
    nil
  end

  def self.valid_uri?(uri)
    uri.scheme.in?(%w[http https]) && uri.host.present? && uri.userinfo.nil? &&
      (uri.port.nil? || uri.port == (uri.scheme == 'https' ? 443 : 80))
  end
  private_class_method :valid_uri?

  def self.strip_tracking(uri)
    uri.fragment = nil
    uri.query_values = uri.query_values(Array)&.reject { |key, _| key.match?(/\A(?:utm_|fbclid\z|gclid\z)/i) }
    uri.query = nil if uri.query.blank?
  end
  private_class_method :strip_tracking

  def initialize(source)
    @source = source
    @host = URI.parse(source.url).host.delete_prefix('www.')
    @domain = PublicSuffix.domain(@host) || @host
    @store_hosts = source.assistant.shopify_store_base_urls.map { |url| URI.parse(url).host.delete_prefix('www.') }
  end

  def within_scope?(url)
    host = URI.parse(url).host.delete_prefix('www.')
    return host == @host unless @source.include_subdomains?

    host == @domain || host.end_with?(".#{@domain}")
  end

  def page?(url)
    !NON_PAGE_EXTENSIONS.match?(URI.parse(url).path)
  end

  def blocked_reason(url)
    uri = URI.parse(url)
    return unless @store_hosts.include?(uri.host.delete_prefix('www.'))
    return if uri.path.in?(['', '/']) || Captain::Documents::CrawlScope::STORE_CONTENT_REGEX.match?(uri.path)

    'managed_catalog'
  end
end
