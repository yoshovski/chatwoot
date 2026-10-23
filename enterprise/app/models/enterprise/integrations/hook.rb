module Enterprise::Integrations::Hook
  extend ActiveSupport::Concern

  prepended do
    before_validation :extract_hubspot_token, if: -> { app_id == 'hubspot' }
    validates :access_token, presence: true, if: -> { app_id == 'hubspot' }
    validate :validate_hubspot_configuration, if: :hubspot_configuration_changed?
  end

  private

  def extract_hubspot_token
    self.settings ||= {}
    token = settings.delete('private_app_token')
    self.access_token = token if token.present?
  end

  def hubspot_configuration_changed?
    app_id == 'hubspot' && enabled? &&
      (new_record? || will_save_change_to_access_token? || will_save_change_to_settings? || will_save_change_to_status?)
  end

  def validate_hubspot_configuration
    return if errors.any?

    Crm::Hubspot::SetupService.new(self).setup
  rescue Crm::Hubspot::Client::ApiError
    errors.add(:base, I18n.t('integration_apps.hubspot.invalid_configuration'))
  end
end
