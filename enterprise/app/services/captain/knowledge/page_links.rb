require 'addressable/uri'

# Link targets worth giving the agent: absolute, without tracking parameters, never the page
# itself, an in-page anchor or a script. Buttons and link lists are collected into one short
# "Links" section per page instead of being embedded with every passage.
class Captain::Knowledge::PageLinks
  TRACKING = /\A(?:utm_|_hs|hs[A-Z]|hsa_|fbclid\z|gclid\z|msclkid\z|mc_[ce]id\z|_ga\z|ref\z)/
  MAX_LINKS = 20

  def initialize(page_url)
    @page = Addressable::URI.parse(page_url.to_s).normalize if page_url.present?
    @links = {}
  end

  # The absolute URL a markdown link target leads to, or nil when it leads nowhere useful.
  def resolve(target)
    # A markdown target can carry a title ("/a "Title"") or angle brackets.
    target = target.to_s.strip.delete_prefix('<').split(/\s+/).first.to_s.delete_suffix('>')
    return target if target.match?(/\A(?:mailto|tel):\S+\z/i)

    uri = @page ? @page.join(target) : Addressable::URI.parse(target)
    return unless uri.scheme.in?(%w[http https]) && uri.host.present?

    url = clean(uri)
    url unless same_page?(url)
  rescue Addressable::URI::InvalidURIError, TypeError, ArgumentError
    nil
  end

  # Keyed without scheme or trailing slash, so http/https copies of one button collapse into the HTTPS one.
  def collect(label, target)
    url = resolve(target)
    label = label.to_s.gsub(/\s+/, ' ').strip
    return unless url && label.present?

    key = url.sub(%r{\Ahttps?://}, '').delete_suffix('/')
    @links[key] = [label, url] if @links.key?(key) ? url.start_with?('https:') : @links.size < MAX_LINKS
  end

  def section
    return if @links.empty?

    "## Links\n\n#{@links.values.map { |label, url| "- #{label}: #{url}" }.join("\n")}"
  end

  private

  def same_page?(url) = @page.present? && url.delete_suffix('/') == @page.omit(:fragment).to_s.delete_suffix('/')

  def clean(uri)
    uri.fragment = nil
    uri.query_values = uri.query_values(Array)&.reject { |key, _| key.match?(TRACKING) }
    uri.query = nil if uri.query.blank?
    uri.normalize.to_s
  end
end
