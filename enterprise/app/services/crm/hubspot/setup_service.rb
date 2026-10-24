class Crm::Hubspot::SetupService
  class InvalidMappingError < StandardError; end

  PROPERTIES_CACHE_TTL = 5.minutes

  def initialize(hook)
    @hook = hook
  end

  def setup
    invalid = @hook.settings.fetch('field_mapping').values - writable_properties.pluck('name')
    raise InvalidMappingError, invalid.join(', ') if invalid.any?
  end

  def writable_properties(refresh: false)
    Rails.cache.delete("hubspot/#{@hook.id}/writable_properties") if refresh
    Rails.cache.fetch("hubspot/#{@hook.id}/writable_properties", expires_in: PROPERTIES_CACHE_TTL) do
      Crm::Hubspot::Client.new(@hook).properties
                          .reject { |property| property.dig('modificationMetadata', 'readOnlyValue') }
                          .map { |property| property.slice('name', 'label', 'type', 'fieldType', 'groupName') }
    end
  end
end
