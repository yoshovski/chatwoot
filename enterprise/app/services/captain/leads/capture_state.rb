# Expose workflow facts without enabling unrestricted contact attributes in the prompt.
class Captain::Leads::CaptureState
  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def captured?
    return false unless @conversation&.additional_attributes&.dig('business_lead_captured') == true

    contact = @conversation.contact
    contact.additional_attributes['lead_assistant_id'] == @assistant.id && Captain::Leads::CaptureReceipt.valid?(@assistant, contact)
  end

  def prompt_context
    { captured: captured?, identity_available: identity_available? }
  end

  def identity_available?
    contact = @conversation&.contact
    contact&.email.present? && !Captain::Conversation::ContactCaptureService.missing_name?(contact)
  end
end
