# Tenant-authored messages. Generated text is valid only for the exact source it was translated from.
class Captain::LocalizedMessages
  FIELDS = %w[
    handoff_message offline_handoff_message no_handoff_message handoff_form_message lead_form_message lead_form_submit resolution_message
  ].freeze
  FORM_COPY_KEYS = %w[
    handoff_prompt handoff_saved submit invalid_field
    fields.name.label fields.name.placeholder fields.email.label fields.email.placeholder
    fields.phone_number.label fields.phone_number.placeholder fields.phone_number.title
  ].map { |suffix| "captain.contact_form.#{suffix}" }.freeze
  SYSTEM_COPY_KEYS = (FORM_COPY_KEYS + %w[
    captain.leads.followup_form captain.leads.followup_submit captain.leads.followup_saved
    captain.reply_languages.retry captain.check_in.default conversations.captain.handoff conversations.captain.no_handoff
    conversations.captain.empty_response_catalog_empty conversations.captain.empty_response_attachments
    conversations.captain.empty_response_unusable conversations.captain.empty_response_handoff
    captain.product_card.view_product captain.product_card.recommendation captain.product_card.recommendations
    captain.action_confirmation.confirm captain.action_confirmation.cancel captain.action_confirmation.confirm_prompt
    captain.action_confirmation.success captain.action_confirmation.failure captain.action_confirmation.cancelled
    conversations.activity.auto_resolution_message
  ]).freeze
  PROTECTED_TOKEN = %r{https?://[^\s)]+|%?\{[\w.]+\}|\{\{.*?\}\}|`[^`]+`|\+?\d[\d.,:/-]*}
  MAX_LENGTH = 2_000

  def initialize(config)
    @config = config
  end

  def text(field, locale)
    @config.dig('localized_messages', field, locale.to_s).presence ||
      generated_text(field, locale) || source(field)
  end

  def generated_text(field, locale)
    return unless @config['auto_translate_messages'] == true

    draft = @config.dig('generated_localized_messages', field, locale.to_s)
    draft['text'] if draft && draft['revision'] == revision(field)
  end

  def source(field)
    return I18n.t(field, locale: :en) if SYSTEM_COPY_KEYS.include?(field)

    value = @config[field]
    value.presence if value.is_a?(String)
  end

  def revision(field) = Digest::SHA256.hexdigest(source(field).to_s)

  def generation_inputs
    return [] unless @config['auto_translate_messages'] == true

    locales = @config['allowed_reply_locales'].presence || Array(@config['default_reply_locale'])
    locales.product(FIELDS + SYSTEM_COPY_KEYS).filter_map do |locale, field|
      [locale, field, revision(field)] if generation_needed?(field, locale)
    end
  end

  def valid_settings?
    enabled = @config.fetch('auto_translate_messages', false)
    return false unless [true, false].include?(enabled)
    return false if enabled && @config['default_reply_locale'].blank?

    valid_overrides?(@config.fetch('localized_messages', {}))
  end

  def self.catalog_text(key, locale)
    copy = I18n.t(key, locale: locale, fallback: false, default: nil, skip_interpolation: true)
    return copy if locale.to_s == 'en'
    return copy if copy.present? && copy != I18n.t(key, locale: :en, skip_interpolation: true)
  end

  def self.valid_translation?(source, translation)
    translation.is_a?(String) && translation.present? && translation.length <= MAX_LENGTH &&
      source.scan(PROTECTED_TOKEN).sort == translation.scan(PROTECTED_TOKEN).sort
  end

  private

  def valid_overrides?(overrides)
    return false unless overrides.is_a?(Hash)

    available = I18n.available_locales.map(&:to_s)
    overrides.all? { |field, values| FIELDS.include?(field) && valid_variants?(values, available) }
  end

  def valid_variants?(values, available)
    values.is_a?(Hash) && values.all? { |locale, text| available.include?(locale) && valid_text?(text) }
  end

  def generation_needed?(field, locale)
    return false if source(field).blank? || @config.dig('localized_messages', field, locale).present?

    SYSTEM_COPY_KEYS.exclude?(field) || self.class.catalog_text(field, locale).blank?
  end

  def valid_text?(text)
    text.is_a?(String) && text.present? && text.length <= MAX_LENGTH
  end
end
