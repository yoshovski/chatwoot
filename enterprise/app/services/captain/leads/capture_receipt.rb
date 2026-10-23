class Captain::Leads::CaptureReceipt
  PURPOSE = 'captain_lead_capture'.freeze

  def self.issue(assistant, contact)
    verifier.generate(fingerprint(assistant, contact), purpose: PURPOSE)
  end

  def self.valid?(assistant, contact)
    receipt = verifier.verified(contact.additional_attributes['lead_capture_receipt'], purpose: PURPOSE)
    receipt.present? && receipt == fingerprint(assistant, contact)
  end

  def self.fingerprint(assistant, contact)
    Digest::SHA256.hexdigest(canonical(payload(assistant, contact)).to_json)
  end

  # JSONB reorders object keys; sign a stable representation before and after persistence.
  def self.canonical(value)
    case value
    when Hash then value.sort.to_h.transform_values { |item| canonical(item) }
    when Array then value.map { |item| canonical(item) }
    else value
    end
  end

  def self.payload(assistant, contact)
    {
      'assistant_id' => assistant.id, 'account_id' => assistant.account_id, 'contact_id' => contact.id,
      'email' => contact.email, 'name' => contact.name,
      'attributes' => contact.custom_attributes.slice('lead_type', 'lead_summary', 'lead_source',
                                                      *assistant.lead_fields.map { |field| "lead_#{field['key']}" }),
      'configuration' => assistant.config.slice('lead_fields', 'lead_types')
    }
  end

  def self.verifier = Rails.application.message_verifier(PURPOSE)
end
