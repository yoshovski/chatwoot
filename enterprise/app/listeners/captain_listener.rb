class CaptainListener < BaseListener
  include ::Events::Types

  def message_created(event)
    message = event.data[:message]
    return if message.blank?

    handle_incoming_message(message) if message.incoming?

    return unless message.human_response? && !message.private?

    ownership_service(message.conversation).record_human_takeover!
  end

  def message_updated(event)
    message = event.data[:message]
    return if message.blank?

    handle_csat_update(message) if message.input_csat?
    handle_suggestion_button_click(message) if message.input_select?
    handle_contact_form_submission(message) if message.form? && message.submitted_values.present?
  end

  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.blank?

    ownership_service(conversation).handle_returned_to_ai! if conversation.pending?
  end

  def assignee_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.blank?
    return unless conversation.assignee_id.blank? && (conversation.ai_assignee.present? || conversation.inbox.captain_active?)
    # Captain's own handoff clears the AI assignee. Only removing the human
    # assignee, or assigning the AI, hands the conversation back to Captain.
    return unless event.data[:changed_attributes].to_h.key?('assignee_id') || conversation.ai_assignee.present?

    ownership_service(conversation).handle_returned_to_ai!
  end

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    ownership_service(conversation).handle_resolved! if conversation.present?

    tracker(conversation).record_resolution(at: event.timestamp)

    assistant = conversation.inbox.captain_assistant

    return unless conversation.inbox.captain_active?

    Captain::Llm::ContactNotesService.new(assistant, conversation).generate_and_update_notes if assistant.config['feature_memory'].present?
    Captain::Llm::ConversationFaqJob.perform_later(conversation, assistant) if assistant.config['feature_faq'].present?
  end

  private

  def handle_csat_update(message)
    response = CsatSurveyResponse.find_by(message: message)
    return unless response

    tracker(message.conversation).record_csat(response: response)
  end

  def handle_suggestion_button_click(message)
    return unless suggestion_click_processable?(message)
    return unless claim_suggestion_click(message)

    conversation = message.conversation
    track_captain_eligibility(conversation, conversation.inbox.captain_assistant)
    Captain::Conversation::ResponseSchedulerService.new(message: message).perform
  end

  def suggestion_click_processable?(message)
    # Choices sent by agents or automations are not Captain's suggestion buttons.
    return false unless message.sender_type == 'Captain::Assistant'
    return false if message.content_attributes&.dig('captain_suggestion_handled')
    return false if message.selected_option_text.blank?

    conversation = message.conversation
    captain_active_for_conversation?(conversation) && ownership_service(conversation).may_reply?
  end

  def captain_active_for_conversation?(conversation)
    return false if conversation.blank?

    inbox = conversation.inbox
    inbox&.captain_assistant.present? && !inbox.external_bot_active?
  end

  def claim_suggestion_click(message)
    message.with_lock do
      return false if message.content_attributes&.dig('captain_suggestion_handled')

      attrs = message.content_attributes.to_h.deep_dup
      attrs['captain_suggestion_handled'] = true
      message.update_columns(content_attributes: attrs) # rubocop:disable Rails/SkipsModelValidations
      true
    end
  end

  def track_captain_eligibility(conversation, assistant)
    return unless conversation.account.feature_enabled?('captain_integration_v2')

    Captain::ConversationOutcomeTracker.new(
      conversation: conversation,
      assistant: assistant
    ).record_eligibility(at: Time.current)
  end

  def ownership_service(conversation)
    Captain::Conversation::OwnershipService.new(conversation: conversation)
  end

  def tracker(conversation)
    Captain::ConversationOutcomeTracker.new(conversation: conversation)
  end

  def contact_capture_service(conversation)
    Captain::Conversation::ContactCaptureService.new(conversation: conversation)
  end

  def handle_incoming_message(message)
    return unless captain_active_for_conversation?(message.conversation)

    contact_capture_service(message.conversation).capture_typed_email!(message)
  end

  def handle_contact_form_submission(message)
    return if message.conversation.blank?

    contact_capture_service(message.conversation).handle_form_submission!(message)
  end
end
