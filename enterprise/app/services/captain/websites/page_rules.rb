# URL-only rules that need no fetch. A reason marks a page as unlikely knowledge;
# administrators can still select it, unlike blocked pages.
class Captain::Websites::PageRules
  TECHNICAL_LABEL = /\A(?:.*api|api.*|auth.*|sso|oauth|login|id|identity|.*sandbox.*|staging|stage|stg|dev|development|test|testing|qa|uat|
                     preview|.*demo.*|status|statuspage|cdn|static|assets?|img|images|connector.*|inapp|webhooks?|admin|app|apps|dashboard|
                     console|portal|my|accounts?|mail|email|smtp|ftp|git|ci|grafana|monitor(?:ing)?)\z/x
  SUPPORT_LABEL = /\A(?:support|help|helpcenter|docs?|documentation|developers?|devdocs|kb|knowledge|knowledgebase|faq|faqs|guides?|learn|academy|
                   manual|wiki)\z/x
  UTILITY_SEGMENT = /\A(?:log-?in|sign-?in|sign_in|sign-?up|sign_up|register|registration|log-?out|sign-?out|password|reset-password|
                     account|accounts|my-account|profile|cart|basket|checkout|search|feed|rss|atom|wp-json|wp-admin|wp-login\.php|cdn-cgi|
                     admin|print|share|requests|unsubscribe)\z/xi
  LISTING_SEGMENT = /\A(?:tags?|categor(?:y|ies)|collections?|sections|authors?|archives?|page)\z/i
  LANGUAGES = %w[ar bg cs da de el en es et fi fr he hi hr hu id it ja ko lt lv ms nb nl no pl pt ro ru sk sl sr sv th tr uk vi zh].freeze
  LOCALE = /\A(#{LANGUAGES.join('|')})(?:[-_][a-z]{2,4})?\z/i

  def self.host_labels(host)
    host = host.delete_prefix('www.')
    domain = PublicSuffix.domain(host) || host
    host.delete_suffix(domain).delete_suffix('.').split('.')
  rescue PublicSuffix::Error
    []
  end

  def self.technical_host?(host) = host_labels(host).any? { |label| label.match?(TECHNICAL_LABEL) }
  def self.support_host?(host) = host_labels(host).any? { |label| label.match?(SUPPORT_LABEL) }

  def self.segments(url) = URI.parse(url).path.to_s.split('/').reject(&:blank?)

  # The first path locale (/de/, /hc/fr-fr/) as a two-letter language code.
  def self.locale(url)
    segments(url).first(2).each { |segment| return Regexp.last_match(1).downcase if segment.match(LOCALE) }
    nil
  end

  # Pages from the same host and first content segment share a section; locale and
  # help-centre prefixes are skipped so /hc/en-us/articles and /articles group together.
  def self.section(url)
    uri = URI.parse(url)
    parts = segments(url)
    parts = parts.drop(1) if parts.first == 'hc'
    parts = parts.drop(1) if parts.first&.match?(LOCALE)
    [uri.host.delete_prefix('www.'), parts.first].compact.join('/')
  end

  def self.reason(url)
    uri = URI.parse(url)
    return 'technical_host' if technical_host?(uri.host)
    return 'query' if uri.query.present?

    parts = segments(url).map(&:downcase)
    return 'utility' if parts.any? { |part| part.match?(UTILITY_SEGMENT) }

    'listing' if listing?(parts)
  end

  # Tag, category and pagination pages, and date archives such as /2019 or /2019/04.
  def self.listing?(parts)
    parts.any? { |part| part.match?(LISTING_SEGMENT) } ||
      (parts.any? && parts.size <= 2 && parts.all? { |part| part.match?(/\A\d{1,4}\z/) })
  end
  private_class_method :listing?
end
