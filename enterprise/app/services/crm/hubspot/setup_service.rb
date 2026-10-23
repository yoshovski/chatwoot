class Crm::Hubspot::SetupService
  def initialize(hook)
    @hook = hook
  end

  def setup
    properties = Crm::Hubspot::Client.new(@hook.access_token).properties
    writable = properties.reject { |property| property.dig('modificationMetadata', 'readOnlyValue') }.pluck('name')
    missing = @hook.settings.fetch('field_mapping').values - writable
    raise Crm::Hubspot::Client::ApiError, 'Mapped HubSpot properties must exist and be writable' if missing.any?
  end
end
