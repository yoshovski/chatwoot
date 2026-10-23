class Api::V1::Accounts::Integrations::HubspotController < Api::V1::Accounts::Integrations::BaseController
  before_action :fetch_hook
  before_action -> { authorize(:hook, :update?) }, only: [:properties, :update]
  before_action -> { authorize(:hook, :destroy?) }, only: [:destroy]

  def properties
    render json: { properties: Crm::Hubspot::SetupService.new(@hook).writable_properties,
                   sources: Crm::Hubspot::MappingSources.new(Current.account).all }
  rescue Crm::Hubspot::Client::ReauthorizationRequired, Crm::Hubspot::Client::AuthorizationError
    render json: { error: 'reauthorize' }, status: :unprocessable_entity
  rescue Crm::Hubspot::Client::ApiError
    render_could_not_create_error(I18n.t('integration_apps.hubspot.unreachable'))
  end

  # Agents read this next to a conversation, so failures come back as states instead of errors.
  def contact
    contact = Current.account.contacts.find(params.require(:contact_id))
    return render json: { error: 'reauthorize' } if @hook.disabled?

    render json: Crm::Hubspot::ContactCardService.new(@hook).perform(contact)
  rescue Crm::Hubspot::Client::ReauthorizationRequired, Crm::Hubspot::Client::AuthorizationError
    render json: { error: 'reauthorize' }
  rescue Crm::Hubspot::Client::ApiError
    render json: { error: 'unavailable' }
  end

  def update
    mapping = settings_params[:field_mapping].to_h
    unless mapping['email'] == 'email' && (mapping.keys - Crm::Hubspot::MappingSources.new(Current.account).keys).empty?
      return render_could_not_create_error(I18n.t('integration_apps.hubspot.invalid_mapping_source'))
    end

    @hook.update!(settings: @hook.settings.merge(settings_params.to_h))
    render partial: 'api/v1/models/hook', formats: [:json], locals: { resource: @hook }
  end

  def destroy
    revoke_refresh_token
    @hook.destroy!
    head :ok
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.find_by!(app_id: 'hubspot')
  end

  def settings_params
    params.require(:settings).permit(:sync_contacts, :save_transcripts, field_mapping: {})
  end

  def revoke_refresh_token
    Crm::Hubspot::OauthClient.new.revoke(@hook.settings['refresh_token'])
  rescue Crm::Hubspot::OauthClient::Error => e
    Rails.logger.warn("HubSpot token revocation failed for hook #{@hook.id}: #{e.message}")
  end
end
