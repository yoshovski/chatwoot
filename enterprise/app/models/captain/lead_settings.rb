module Captain::LeadSettings
  extend ActiveSupport::Concern

  BOOLEAN_VALUES = [true, false, nil].freeze

  included do
    validate :validate_lead_settings
    after_save :ensure_lead_attribute_definitions, if: :leads_enabled?
  end

  def leads_enabled? = config['leads_enabled'] == true
  def lead_fields = config.fetch('lead_fields', [])
  def lead_types = config.fetch('lead_types', [])
  def lead_max_questions = config.fetch('lead_max_questions', 2)

  def lead_prompt_context
    return {} unless leads_enabled?

    { lead_capture: { fields: lead_fields, types: lead_types, max_questions: lead_max_questions,
                      handoff_capture: config['lead_handoff_capture_enabled'] == true } }
  end

  private

  def validate_lead_settings
    # Agents saved before HubSpot synced every contact may still carry lead_hubspot_sync_enabled; it is ignored.
    valid = valid_lead_switches?
    valid &&= valid_lead_notification_team?
    valid &&= valid_lead_questions?
    valid &&= valid_lead_collections?
    valid &&= !leads_enabled? || lead_types.present?
    errors.add(:config, I18n.t('captain.leads.invalid_settings')) unless valid
  end

  def valid_lead_switches?
    %w[leads_enabled lead_handoff_capture_enabled published_pricing_enabled].all? { |key| BOOLEAN_VALUES.include?(config[key]) }
  end

  def valid_lead_notification_team?
    team_id = config['lead_notification_team_id']
    team_id.nil? || (team_id.is_a?(Integer) && account.teams.exists?(id: team_id))
  end

  def valid_lead_collections?
    valid_lead_entries?(lead_fields, %w[key label]) && valid_lead_entries?(lead_types, %w[name rule]) &&
      valid_lead_field_keys? && unique_lead_entries?
  end

  def valid_lead_questions? = lead_max_questions.is_a?(Integer) && lead_max_questions.between?(0, 5)

  def valid_lead_entries?(entries, keys)
    entries.is_a?(Array) && entries.size <= 10 && entries.all? { |entry| valid_lead_entry?(entry, keys) }
  end

  def valid_lead_entry?(entry, keys)
    entry.is_a?(Hash) && entry.keys.sort == keys.sort && keys.all? { |key| valid_lead_text?(entry[key]) }
  end

  def valid_lead_text?(value) = value.is_a?(String) && value.strip.present? && value.length <= 300

  def valid_lead_field_keys?
    lead_fields.all? do |field|
      field['key'].match?(/\A[a-z][a-z0-9_]{0,39}\z/) && %w[type summary source status].exclude?(field['key'])
    end
  end

  def unique_lead_entries?
    lead_fields.pluck('key').uniq.size == lead_fields.size && lead_types.pluck('name').uniq.size == lead_types.size
  end

  def ensure_lead_attribute_definitions
    attributes = lead_fields.map { |field| ["lead_#{field['key']}", field['label'], 'text'] }
    attributes += %w[type summary source status].map { |key| ["lead_#{key}", I18n.t("captain.leads.attributes.#{key}"), 'text'] }
    attributes.each do |key, label, type|
      account.custom_attribute_definitions.find_or_create_by!(attribute_key: key, attribute_model: 'contact_attribute') do |definition|
        definition.attribute_display_name = label
        definition.attribute_display_type = type
      end
    end
  end
end
