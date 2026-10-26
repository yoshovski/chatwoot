class IpLookupService
  def perform(ip_address)
    return if ip_address.blank? || !ClientIpResolver.public_ip?(ip_address) || !ip_lookup_available?

    Geocoder.search(ip_address).first
  rescue StandardError => e
    Rails.logger.warn "Exception: IP resolution failed :#{e.message}"
    nil
  end

  private

  def ip_lookup_available?
    File.exist?(GeocoderConfiguration::LOOK_UP_DB) || ENV['IP_LOOKUP_API_KEY'].blank?
  end
end
