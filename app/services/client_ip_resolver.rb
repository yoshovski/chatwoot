# frozen_string_literal: true

class ClientIpResolver
  IP_HEADERS = %w[
    HTTP_CF_CONNECTING_IP
    HTTP_TRUE_CLIENT_IP
    HTTP_X_CLIENT_IP
    HTTP_X_FORWARDED_FOR
    HTTP_X_REAL_IP
  ].freeze

  COUNTRY_HEADERS = %w[
    HTTP_CF_IPCOUNTRY
    HTTP_X_COUNTRY_CODE
  ].freeze

  CITY_HEADERS = %w[
    HTTP_CF_IPCITY
    HTTP_X_CITY
  ].freeze

  IGNORED_COUNTRY_CODES = %w[XX T1].freeze

  def self.ip_from(request)
    return if request.blank?

    candidates = header_ip_candidates(request)
    candidates << request.remote_ip if request.respond_to?(:remote_ip)
    candidates.find { |ip| public_ip?(ip) } || request.remote_ip
  end

  def self.public_ip?(ip_string)
    addr = parse_ip(ip_string)
    return false unless addr

    !addr.private? && !addr.loopback? && !addr.link_local? && !unspecified_ip?(addr)
  end

  def self.header_location(request)
    return {} if request.blank?

    country_code = extract_country_code(request)
    city = extract_city(request)
    {
      'country_code' => country_code,
      'country' => country_name_for(country_code),
      'city' => city.presence
    }.compact
  end

  def self.contact_attributes_from(request)
    ip = ip_from(request)
    attrs = ip.present? ? { 'created_at_ip' => ip } : {}
    attrs.merge(header_location(request))
  end

  def self.refresh_contact_ip!(contact, request)
    return unless refreshable_contact?(contact)

    current_ip = ip_from(request)
    current_attrs = contact.additional_attributes || {}
    attrs = updated_contact_attributes(current_attrs, current_ip, request)
    return if attrs == current_attrs

    contact.update!(additional_attributes: attrs)
    enqueue_lookup_if_needed(contact, current_ip, current_attrs, attrs)
  end

  def self.country_name_for(country_code)
    code = country_code.to_s.strip.upcase
    return if code.blank? || IGNORED_COUNTRY_CODES.include?(code)

    TZInfo::Country.get(code).name
  rescue TZInfo::InvalidCountryCode
    nil
  end

  def self.refreshable_contact?(contact)
    contact.present? && contact.account&.feature_enabled?('ip_lookup')
  end
  private_class_method :refreshable_contact?

  def self.updated_contact_attributes(current_attrs, current_ip, request)
    attrs = current_attrs.deep_dup
    previous_ip = attrs['updated_at_ip'].presence || attrs['created_at_ip'].presence
    apply_updated_ip!(attrs, current_ip, previous_ip)
    attrs.merge!(header_location(request))
  end
  private_class_method :updated_contact_attributes

  def self.enqueue_lookup_if_needed(contact, current_ip, old_attrs, new_attrs)
    return unless public_ip?(current_ip)

    old_ip = old_attrs['updated_at_ip'].presence || old_attrs['created_at_ip'].presence
    ContactIpLookupJob.perform_later(contact) if current_ip != old_ip || new_attrs['city'].blank?
  end
  private_class_method :enqueue_lookup_if_needed

  def self.apply_updated_ip!(attrs, current_ip, previous_ip)
    return false unless public_ip?(current_ip)

    changed = current_ip != previous_ip
    attrs['updated_at_ip'] = current_ip if changed
    attrs['created_at_ip'] = current_ip unless public_ip?(attrs['created_at_ip'])
    changed
  end
  private_class_method :apply_updated_ip!

  def self.header_ip_candidates(request)
    env = request.respond_to?(:env) ? request.env : {}
    IP_HEADERS.flat_map do |header|
      env[header].to_s.split(',').filter_map { |raw| normalize_ip_token(raw) }
    end
  end
  private_class_method :header_ip_candidates

  def self.normalize_ip_token(raw)
    token = raw.to_s.strip
    return if token.blank?

    if token.start_with?('[') && token.include?(']')
      token[1...token.index(']')]
    elsif token.count(':') == 1 && token.match?(/\A\d+\.\d+\.\d+\.\d+:\d+\z/)
      token.split(':').first
    else
      token
    end
  end
  private_class_method :normalize_ip_token

  def self.parse_ip(ip_string)
    cleaned = normalize_ip_token(ip_string)
    return if cleaned.blank?

    IPAddr.new(cleaned)
  rescue IPAddr::Error
    nil
  end
  private_class_method :parse_ip

  def self.unspecified_ip?(addr)
    addr == IPAddr.new('0.0.0.0') || addr == IPAddr.new('::')
  end
  private_class_method :unspecified_ip?

  def self.extract_country_code(request)
    env = request.respond_to?(:env) ? request.env : {}
    code = COUNTRY_HEADERS.lazy.map { |h| env[h].to_s.strip.upcase }.find(&:present?)
    return if code.blank? || IGNORED_COUNTRY_CODES.include?(code)

    code
  end
  private_class_method :extract_country_code

  def self.extract_city(request)
    env = request.respond_to?(:env) ? request.env : {}
    CITY_HEADERS.lazy.map { |h| env[h].to_s.strip }.find(&:present?)
  end
  private_class_method :extract_city
end
