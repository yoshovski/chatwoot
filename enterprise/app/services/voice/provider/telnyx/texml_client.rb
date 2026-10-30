# TeXML REST calls for a Telnyx voice inbox. TeXML mirrors Twilio's call API, so the account
# UUID sits in the path where Twilio puts its AccountSid.
# https://developers.telnyx.com/api-reference/texml-rest-commands/initiate-an-outbound-call
class Voice::Provider::Telnyx::TexmlClient
  SIP_DOMAIN = 'sip.telnyx.com'.freeze

  def initialize(channel)
    @channel = channel
  end

  # Telnyx answers this request without a CallSid, so callers correlate the call through
  # the query string they put on `url` and `status_callback`.
  def create_call(to:, url:, status_callback: nil, status_callback_events: nil)
    body = {
      To: to,
      From: @channel.phone_number,
      ApplicationSid: config['texml_application_id'],
      Url: url,
      UrlMethod: 'POST',
      StatusCallback: status_callback,
      StatusCallbackMethod: status_callback && 'POST',
      StatusCallbackEvent: status_callback_events
    }.compact
    api.post("#{calls_path}/Calls", body)
  end

  def hangup(call_sid)
    api.post_form("#{calls_path}/Calls/#{call_sid}", Status: 'completed')
  rescue ::Telnyx::ApiClient::Error => e
    # 404/422 mean the leg is already gone, which is what we wanted.
    raise unless [404, 422].include?(e.status)
  end

  def self.sip_uri(sip_username)
    "sip:#{sip_username}@#{SIP_DOMAIN}"
  end

  private

  def calls_path
    account_sid = config['account_sid']
    raise ArgumentError, 'Telnyx account ID is required for voice calls' if account_sid.blank?

    "/texml/Accounts/#{account_sid}"
  end

  def config
    @channel.provider_config
  end

  def api
    @api ||= ::Telnyx::ApiClient.new(config['api_key'])
  end
end
