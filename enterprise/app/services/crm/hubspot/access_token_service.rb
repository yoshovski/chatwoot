# HubSpot access tokens last about 30 minutes. Refresh shortly before expiry, one worker at a time per hook.
class Crm::Hubspot::AccessTokenService
  EXPIRY_BUFFER = 1.minute
  LOCK_TIMEOUT = 20.seconds

  def initialize(hook)
    @hook = hook
  end

  # Pass the token HubSpot just rejected to force a refresh, unless another worker already replaced it.
  def access_token(rejected_token: nil)
    return @hook.access_token unless refresh_needed?(rejected_token)

    lock_key = format(::Redis::Alfred::HUBSPOT_TOKEN_REFRESH_MUTEX, hook_id: @hook.id)
    lock_manager = Redis::LockManager.new
    raise Crm::Hubspot::Client::ApiError, 'HubSpot token refresh already in progress' unless lock_manager.lock(lock_key, LOCK_TIMEOUT)

    begin
      @hook.reload
      refresh_needed?(rejected_token) ? refresh! : @hook.access_token
    ensure
      lock_manager.unlock(lock_key)
    end
  end

  private

  def refresh_needed?(rejected_token)
    return true if rejected_token.present? && rejected_token == @hook.access_token

    expires_on = @hook.settings['expires_on']
    expires_on.blank? || Time.zone.parse(expires_on) <= EXPIRY_BUFFER.from_now
  end

  def refresh!
    tokens = Crm::Hubspot::OauthClient.new.refresh(@hook.settings.fetch('refresh_token'))
    @hook.update!(access_token: tokens.fetch('access_token'), settings: @hook.settings.merge(
      'refresh_token' => tokens['refresh_token'].presence || @hook.settings['refresh_token'],
      'expires_on' => tokens.fetch('expires_in').to_i.seconds.from_now.utc.iso8601
    ))
    @hook.access_token
  rescue Crm::Hubspot::OauthClient::InvalidGrantError
    @hook.update!(status: :disabled, settings: @hook.settings.merge('reauthorization_required' => true))
    raise Crm::Hubspot::Client::ReauthorizationRequired, 'HubSpot connection must be reauthorized'
  rescue Crm::Hubspot::OauthClient::Error => e
    raise Crm::Hubspot::Client::ApiError, e.message
  end
end
