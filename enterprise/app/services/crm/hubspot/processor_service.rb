class Crm::Hubspot::ProcessorService < Crm::BaseProcessorService
  def self.crm_name = 'hubspot'

  def handle_contact(contact)
    return unless @hook.settings['sync_contacts'] && eligible_contact?(contact)

    upsert_contact(contact)
  end

  # Returns the HubSpot contact id. Skips the API call when nothing changed since the last sync.
  def upsert_contact(contact)
    contact.with_lock do
      properties = mapped_properties(contact)
      fingerprint = Digest::SHA256.hexdigest([@hook.id, contact.email, properties.sort].to_json)
      external_id = get_external_id(contact)
      unless external_id.present? && contact.additional_attributes['hubspot_sync_fingerprint'] == fingerprint
        external_id = Crm::Hubspot::Client.new(@hook).upsert_contact(contact.email, properties)
        store_sync_result(contact, external_id, fingerprint)
      end
      external_id
    end
  end

  # Keyed by resolve time: a retried job finds its note, a later resolve gets a new one.
  def handle_conversation_resolved(conversation, resolved_at)
    contact = conversation.contact
    return unless @hook.settings['save_transcripts'] && eligible_contact?(contact)
    return if @hook.settings['contact_sync_scope'] == 'business_leads' && conversation.additional_attributes['business_lead_captured'] != true

    key = resolved_at.utc.iso8601
    return if conversation.additional_attributes.dig('hubspot_note_ids', key)

    note_id = Crm::Hubspot::Client.new(@hook).create_note(
      upsert_contact(contact), body: Crm::Hubspot::Mappers::TranscriptNoteMapper.new(conversation).body, timestamp: resolved_at
    )
    conversation.with_lock do
      attributes = conversation.additional_attributes.deep_dup
      attributes['hubspot_note_ids'] = attributes.fetch('hubspot_note_ids', {}).merge(key => note_id)
      conversation.update!(additional_attributes: attributes)
    end
  end

  private

  def eligible_contact?(contact)
    contact.email.present? && (@hook.settings['contact_sync_scope'] != 'business_leads' || verified_lead?(contact))
  end

  def store_sync_result(contact, external_id, fingerprint)
    attributes = contact.additional_attributes.deep_dup
    attributes['external'] = attributes.fetch('external', {}).merge('hubspot_id' => external_id)
    attributes['hubspot_sync_fingerprint'] = fingerprint
    attributes['hubspot_sync_status'] = 'synced'
    contact.update!(additional_attributes: attributes)
  end

  # Like Tidio, blank values never overwrite what is already in HubSpot.
  def mapped_properties(contact)
    values = source_values(contact)
    @hook.settings.fetch('field_mapping').each_with_object({}) do |(source, destination), properties|
      value = values[source]
      properties[destination] = value.to_s unless value.nil? || value == ''
    end
  end

  def source_values(contact)
    first, last = contact.name.to_s.split(' ', 2)
    attributes = contact.custom_attributes.to_h
    # Widget visitors can set custom attributes, so lead fields only go out with a valid capture receipt.
    attributes = attributes.reject { |key, _| key.start_with?('lead_') } unless verified_lead?(contact)
    attributes.merge('email' => contact.email, 'firstname' => first, 'lastname' => last, 'phone' => contact.phone_number,
                     'lead_source' => 'chatbot')
  end

  def verified_lead?(contact)
    return false unless contact.custom_attributes['lead_status'] == 'captured'

    assistant = @account.captain_assistants.find_by(id: contact.additional_attributes['lead_assistant_id'])
    assistant.present? && Captain::Leads::CaptureReceipt.valid?(assistant, contact)
  end
end
