module Concerns::SafeEndpointValidatable
  extend ActiveSupport::Concern

  FRONTEND_HOST = URI.parse(ENV.fetch('FRONTEND_URL', 'http://localhost:3000')).host.freeze
  DISALLOWED_HOSTS = ['localhost', /\.local\z/i].freeze

  included do
    validate :validate_safe_endpoint_url
  end

  private

  def validate_safe_endpoint_url
    return if endpoint_url.blank?

    safe_endpoint_errors(endpoint_url).each { |message| errors.add(:endpoint_url, message) }
  end

  # The reasons a URL (which may hold Liquid placeholders) is not a safe outbound endpoint; empty when it is.
  def safe_endpoint_errors(url)
    uri = parse_endpoint_uri(url)
    return ['must be a valid URL'] unless uri

    [endpoint_scheme_error(uri), endpoint_host_error(uri), ip_address_error(uri), unicode_error(uri)].compact
  end

  def parse_endpoint_uri(url)
    # Strip Liquid template syntax for validation
    # Replace {{ variable }} with a placeholder value
    sanitized_url = url.gsub(/\{\{[^}]+\}\}/, 'placeholder')
    URI.parse(sanitized_url)
  rescue URI::InvalidURIError
    nil
  end

  def endpoint_scheme_error(uri)
    'must use HTTPS protocol' unless uri.scheme == 'https'
  end

  def endpoint_host_error(uri)
    return 'must have a valid hostname' if uri.host.blank?
    return 'cannot point to the application itself' if uri.host == FRONTEND_HOST

    disallowed = DISALLOWED_HOSTS.any? { |pattern| pattern.is_a?(Regexp) ? uri.host =~ pattern : uri.host.downcase == pattern }
    'cannot use disallowed hostname' if disallowed
  end

  def ip_address_error(uri)
    return if uri.host.blank?
    return unless /\A\d+\.\d+\.\d+\.\d+\z/.match?(uri.host) || uri.host.include?(':')

    'cannot be an IP address, must be a hostname'
  end

  def unicode_error(uri)
    return unless uri.host
    return if /\A[\x00-\x7F]+\z/.match?(uri.host)

    'hostname cannot contain non-ASCII characters'
  end
end
