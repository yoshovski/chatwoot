# Telnyx hands out pre-signed recording URLs, so the download only needs the API key when the
# URL points at the Telnyx API itself (a signed storage URL rejects an extra Authorization header).
class Voice::Provider::Telnyx::RecordingAttachmentService < Voice::Provider::Twilio::RecordingAttachmentService
  private

  def fetch_options
    options = { allowed_content_type_prefixes: ALLOWED_CONTENT_TYPE_PREFIXES }
    return options unless telnyx_api_url?

    options.merge(headers: { 'Authorization' => "Bearer #{channel.provider_config['api_key']}" }, sensitive_headers: ['Authorization'])
  end

  def telnyx_api_url?
    URI.parse(recording_url).host == URI.parse(::Telnyx::ApiClient::BASE_URL).host
  rescue URI::InvalidURIError
    false
  end
end
