class Captain::Leads::CaptureService
  def initialize(assistant, contact)
    @assistant = assistant
    @contact = contact
  end

  def perform(name:, email:, lead_type:, summary:, fields:)
    @assistant.reload
    raise ArgumentError, 'Lead capture is disabled' unless @assistant.leads_enabled?
    raise ArgumentError, 'Contact belongs to another account' unless @contact.account_id == @assistant.account_id

    validate_details!(name, email, lead_type, summary, fields)
    email = email.strip.downcase
    attributes = fields.transform_keys { |key| "lead_#{key}" }.merge(
      'lead_type' => lead_type, 'lead_summary' => summary_with_location(summary), 'lead_source' => 'chatbot',
      'lead_status' => 'captured',
      **visitor_location
    )
    @contact.with_lock do
      @contact.assign_attributes(name: name.strip, email: email, custom_attributes: @contact.custom_attributes.merge(attributes))
      @contact.additional_attributes = @contact.additional_attributes.merge(
        'lead_assistant_id' => @assistant.id,
        'lead_capture_receipt' => Captain::Leads::CaptureReceipt.issue(@assistant, @contact)
      )
      @contact.save!
    end
    'Lead details saved. Email is unverified. If HubSpot is connected, sync runs in the background; delivery is not confirmed.'
  end

  def validate_qualification!(lead_type, summary, fields)
    valid = valid_text?(summary, 2000) && @assistant.lead_types.pluck('name').include?(lead_type) && valid_fields?(fields)
    raise ArgumentError, 'Provide a summary, configured lead type and configured fields only' unless valid
  end

  private

  def summary_with_location(summary)
    location = @contact.additional_attributes.values_at('city', 'country').compact_blank.join(', ')
    return summary.strip if location.blank?

    location_summary = I18n.t('captain.leads.visitor_location_summary', location: location)
    return summary.strip if summary.strip.end_with?(location_summary)

    [summary.strip, location_summary].join("\n")
  end

  # Visitor geography is detected context, never the company's registered country.
  def visitor_location
    @contact.additional_attributes.slice('city', 'country', 'country_code').each_with_object({}) do |(key, value), location|
      location["lead_visitor_#{key}"] = value if value.present?
    end
  end

  def validate_details!(name, email, lead_type, summary, fields)
    valid = [name, email, summary].all? { |value| valid_text?(value, 2000) }
    valid &&= email.strip.match?(URI::MailTo::EMAIL_REGEXP)
    validate_qualification!(lead_type, summary, fields)
    raise ArgumentError, 'Provide a name, email, summary, configured lead type and configured fields only' unless valid
  end

  def valid_fields?(fields)
    fields.is_a?(Hash) && (fields.keys - @assistant.lead_fields.pluck('key')).empty? &&
      fields.values.all? { |value| valid_text?(value, 1000) }
  end

  def valid_text?(value, maximum) = value.is_a?(String) && value.strip.present? && value.length <= maximum
end
