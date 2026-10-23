class Hubspot::CallbacksController < ApplicationController
  DEFAULT_SETTINGS = {
    'field_mapping' => { 'email' => 'email', 'firstname' => 'firstname', 'lastname' => 'lastname', 'phone' => 'phone' },
    'sync_contacts' => true,
    'save_transcripts' => true
  }.freeze

  def show
    return redirect_to(frontend_url) if account.blank?

    connect!
    redirect_to integration_url
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    redirect_to "#{integration_url}?error=1"
  end

  private

  def connect!
    raise ArgumentError, 'Missing HubSpot authorization code' if params[:code].blank?

    oauth_client = Crm::Hubspot::OauthClient.new
    tokens = oauth_client.exchange_code(params[:code])
    details = oauth_client.introspect(tokens.fetch('access_token'))
    hook = account.hooks.find_or_initialize_by(app_id: 'hubspot')
    hook.update!(
      access_token: tokens.fetch('access_token'),
      status: :enabled,
      settings: DEFAULT_SETTINGS.merge(hook.settings.to_h.except('reauthorization_required')).merge(token_settings(tokens, details))
    )
  end

  def token_settings(tokens, details)
    {
      'refresh_token' => tokens.fetch('refresh_token'),
      'expires_on' => tokens.fetch('expires_in').to_i.seconds.from_now.utc.iso8601,
      'portal_id' => details.fetch('hub_id'),
      'hub_domain' => details['hub_domain'],
      'user' => details['user'],
      'scopes' => details.fetch('scopes')
    }.compact
  end

  def account
    @account ||= GlobalID::Locator.locate_signed(params[:state].to_s, for: 'default', only: Account)
  end

  def integration_url
    "#{frontend_url}/app/accounts/#{account.id}/settings/integrations/hubspot"
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
