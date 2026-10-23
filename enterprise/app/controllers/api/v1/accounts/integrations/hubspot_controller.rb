class Api::V1::Accounts::Integrations::HubspotController < Api::V1::Accounts::Integrations::BaseController
  before_action :fetch_hook
  before_action -> { authorize(:hook, :destroy?) }, only: [:destroy]

  def destroy
    revoke_refresh_token
    @hook.destroy!
    head :ok
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.find_by!(app_id: 'hubspot')
  end

  def revoke_refresh_token
    Crm::Hubspot::OauthClient.new.revoke(@hook.settings['refresh_token'])
  rescue Crm::Hubspot::OauthClient::Error => e
    Rails.logger.warn("HubSpot token revocation failed for hook #{@hook.id}: #{e.message}")
  end
end
