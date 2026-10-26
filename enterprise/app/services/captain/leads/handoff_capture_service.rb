# A signed, conversation-bound business inquiry survives the handoff while the form collects identity.
# Nothing is captured or sent to the CRM until a real name and email are available.
class Captain::Leads::HandoffCaptureService
  PURPOSE = 'captain_business_handoff'.freeze

  def initialize(conversation, assistant)
    @conversation = conversation
    @assistant = assistant
  end

  def stage!(lead_type:, summary:, fields:)
    return unless enabled?

    Captain::Leads::CaptureService.new(@assistant, @conversation.contact).validate_qualification!(lead_type, summary, fields)
    payload = { 'conversation_id' => @conversation.id, 'account_id' => @assistant.account_id, 'assistant_id' => @assistant.id,
                'lead_type' => lead_type, 'summary' => summary, 'fields' => fields }
    @conversation.with_lock do
      return if @conversation.additional_attributes['business_lead_captured']

      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
        attribute_key => verifier.generate(payload, purpose: self.class::PURPOSE, expires_in: 7.days)
      ))
    end
    complete!
  end

  def complete!(name: nil, email: nil)
    return unless enabled?

    @conversation.with_lock do
      payload = verified_payload
      return unless payload

      contact = @conversation.contact.reload
      name ||= contact_identity_name(contact)
      email ||= contact.email
      return if name.blank? || email.blank?

      capture!(contact, payload, name: name, email: email)
    end
  end

  private

  def contact_identity_name(contact)
    contact.name unless Captain::Conversation::ContactCaptureService.missing_name?(contact)
  end

  def verified_payload
    payload = verifier.verified(@conversation.additional_attributes[attribute_key], purpose: self.class::PURPOSE)
    payload if payload && payload.values_at('conversation_id', 'account_id', 'assistant_id') ==
                          [@conversation.id, @assistant.account_id, @assistant.id]
  end

  def capture!(contact, payload, name:, email:)
    Captain::Leads::CaptureService.new(@assistant, contact).perform(
      name: name, email: email, lead_type: payload['lead_type'], summary: payload['summary'], fields: payload['fields']
    )
    Captain::Leads::DeliveryService.new(@assistant, @conversation).perform(lead_type: payload['lead_type'], summary: payload['summary'])
  end

  def enabled?
    @assistant&.leads_enabled? && @assistant.config['lead_handoff_capture_enabled'] == true && @conversation.account_id == @assistant.account_id
  end

  def attribute_key = 'business_handoff'

  def verifier = Rails.application.message_verifier(self.class::PURPOSE)
end
