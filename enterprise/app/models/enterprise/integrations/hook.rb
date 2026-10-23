module Enterprise::Integrations::Hook
  extend ActiveSupport::Concern

  prepended do
    validates :access_token, presence: true, if: -> { app_id == 'hubspot' }
    validate :validate_hubspot_field_mapping, if: :hubspot_field_mapping_changed?
  end

  private

  # Token refreshes also rewrite settings; only a changed mapping needs a round trip to HubSpot.
  def hubspot_field_mapping_changed?
    app_id == 'hubspot' && enabled? && persisted? &&
      settings.to_h['field_mapping'] != settings_in_database.to_h['field_mapping']
  end

  def validate_hubspot_field_mapping
    return if errors.any?

    destinations = settings['field_mapping'].values
    return errors.add(:base, I18n.t('integration_apps.hubspot.duplicate_mapping')) if destinations.uniq.size != destinations.size

    Crm::Hubspot::SetupService.new(self).setup
  rescue Crm::Hubspot::SetupService::InvalidMappingError => e
    errors.add(:base, I18n.t('integration_apps.hubspot.invalid_mapping', properties: e.message))
  rescue Crm::Hubspot::Client::ApiError, Crm::Hubspot::Client::ReauthorizationRequired
    errors.add(:base, I18n.t('integration_apps.hubspot.unreachable'))
  end
end
