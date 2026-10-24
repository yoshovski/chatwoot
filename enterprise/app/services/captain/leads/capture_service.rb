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
      'lead_type' => lead_type, 'lead_summary' => summary.strip, 'lead_source' => 'chatbot',
      'lead_status' => 'captured'
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

  private

  def validate_details!(name, email, lead_type, summary, fields)
    valid = [name, email, summary].all? { |value| valid_text?(value, 2000) }
    valid &&= email.strip.match?(URI::MailTo::EMAIL_REGEXP)
    valid &&= @assistant.lead_types.pluck('name').include?(lead_type) && valid_fields?(fields)
    raise ArgumentError, 'Provide a name, email, summary, configured lead type and configured fields only' unless valid
  end

  def valid_fields?(fields)
    fields.is_a?(Hash) && (fields.keys - @assistant.lead_fields.pluck('key')).empty? &&
      fields.values.all? { |value| valid_text?(value, 1000) }
  end

  def valid_text?(value, maximum) = value.is_a?(String) && value.strip.present? && value.length <= maximum
end
