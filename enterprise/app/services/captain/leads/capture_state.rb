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
    { captured: captured?, identity_available: identity_available?,
      form_pending: form_pending?,
      unsubmitted_turns: unsubmitted_turns }
  end

  def form_pending?
    return false unless @conversation

    Captain::Leads::FollowupFormService.new(@assistant, @conversation).pending? ||
      contact_capture_form_pending?
  end

  def unsubmitted_turns
    Captain::Conversation::ContactCaptureService.new(
      conversation: @conversation,
      assistant: @assistant
    ).unsubmitted_turns_count
  end

  def contact_capture_form_pending?
    return false unless @conversation

    capture = Captain::Conversation::ContactCaptureService.new(conversation: @conversation, assistant: @assistant)
    last_form = @conversation.messages.where(content_type: :form).reorder(id: :desc).first
    last_form.present? && capture.form_active?(last_form)
  end

  def identity_available?
    contact = @conversation&.contact
    contact&.email.present? && !Captain::Conversation::ContactCaptureService.missing_name?(contact)
  end
end
