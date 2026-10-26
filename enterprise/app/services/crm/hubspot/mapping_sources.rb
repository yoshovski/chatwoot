# The contact fields an admin can map to HubSpot properties.
class Crm::Hubspot::MappingSources
  STANDARD_KEYS = %w[email firstname lastname phone lead_type lead_summary lead_source].freeze

  def initialize(account)
    @account = account
  end

  def all
    sources = STANDARD_KEYS.map { |key| { 'key' => key, 'label' => I18n.t("integration_apps.hubspot.sources.#{key}"), 'kind' => 'standard' } }
    sources += %w[visitor_city visitor_country visitor_country_code].map do |key|
      { 'key' => "lead_#{key}", 'label' => I18n.t("captain.leads.attributes.#{key}"), 'kind' => 'lead' }
    end
    sources += lead_fields.map { |field| { 'key' => "lead_#{field['key']}", 'label' => field['label'], 'kind' => 'lead' } }
    sources += @account.custom_attribute_definitions.where(attribute_model: 'contact_attribute').map do |definition|
      { 'key' => definition.attribute_key, 'label' => definition.attribute_display_name, 'kind' => 'attribute' }
    end
    sources.uniq { |source| source['key'] }
  end

  def keys = all.pluck('key')

  private

  def lead_fields
    @account.captain_assistants.flat_map(&:lead_fields)
  end
end
