# Checks a captcha token from the sign-up and resend-confirmation forms. Cloudflare Turnstile when its secret is set,
# otherwise hCaptcha. Public signup stays off without one of them (GlobalConfigService.account_signup_enabled?).
class ChatwootCaptcha
  VERIFY_URLS = {
    'turnstile' => 'https://challenges.cloudflare.com/turnstile/v0/siteverify',
    'hcaptcha' => 'https://hcaptcha.com/siteverify'
  }.freeze
  SECRET_KEYS = { 'turnstile' => 'TURNSTILE_SECRET_KEY', 'hcaptcha' => 'HCAPTCHA_SERVER_KEY' }.freeze
  SITE_KEYS = { 'turnstile' => 'TURNSTILE_SITE_KEY', 'hcaptcha' => 'HCAPTCHA_SITE_KEY' }.freeze

  # The provider whose secret is set, Turnstile first; nil when neither is.
  def self.provider
    SECRET_KEYS.find { |_provider, key| GlobalConfigService.load(key, '').present? }&.first
  end

  def self.configured?
    provider.present?
  end

  # What the sign-up page needs to show the widget: { provider:, site_key: }, or {} without a captcha.
  def self.frontend_config
    return {} unless provider

    { provider: provider, site_key: GlobalConfigService.load(SITE_KEYS[provider], '') }
  end

  def initialize(client_response, remote_ip: nil)
    @client_response = client_response
    @remote_ip = remote_ip
    @provider = self.class.provider
  end

  def valid?
    return true if @provider.nil?
    return false if @client_response.blank?

    response = HTTParty.post(VERIFY_URLS[@provider], body: {
      response: @client_response, secret: GlobalConfigService.load(SECRET_KEYS[@provider], ''), remoteip: @remote_ip
    }.compact, timeout: 10)
    response.success? && response.parsed_response['success'] == true
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
    false
  end
end
