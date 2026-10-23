class Crm::Hubspot::ProcessorService < Crm::BaseProcessorService
  def self.crm_name = 'hubspot'

  def handle_contact(contact)
    contact.with_lock do
      assistant = @account.captain_assistants.find_by(id: contact.additional_attributes['lead_assistant_id'])
      return unless eligible_lead?(assistant, contact)

      properties = mapped_properties(contact)
      fingerprint = Digest::SHA256.hexdigest([@hook.id, contact.email, properties.sort].to_json)
      return if contact.additional_attributes['hubspot_sync_fingerprint'] == fingerprint

      external_id = Crm::Hubspot::Client.new(@hook.access_token).upsert_contact(contact.email, properties)
      store_sync_result(contact, external_id, fingerprint)
    end
  end

  private

  def store_sync_result(contact, external_id, fingerprint)
    attributes = contact.additional_attributes.deep_dup
    attributes['external'] = attributes.fetch('external', {}).merge('hubspot_id' => external_id)
    attributes['hubspot_sync_fingerprint'] = fingerprint
    attributes['hubspot_sync_status'] = 'synced'
    contact.update!(additional_attributes: attributes)
  end

  def eligible_lead?(assistant, contact)
    assistant&.leads_enabled? && assistant.hubspot_sync_enabled? &&
      contact.custom_attributes['lead_status'] == 'captured' && Captain::Leads::CaptureReceipt.valid?(assistant, contact)
  end

  def mapped_properties(contact)
    first, last = contact.name.split(' ', 2)
    values = contact.custom_attributes.merge('email' => contact.email, 'firstname' => first, 'lastname' => last,
                                             'lead_source' => 'chatbot')
    @hook.settings.fetch('field_mapping').to_h do |source, destination|
      [destination, values[source]]
    end.compact
  end
end
