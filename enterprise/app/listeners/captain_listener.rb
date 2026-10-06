class CaptainListener < BaseListener
  include ::Events::Types

  def message_created(event)
    message = event.data[:message]
    return if message.blank?
    return unless message.human_response? && !message.private?

    ownership_service(message.conversation).record_human_takeover!
  end

  def message_updated(event)
    message = event.data[:message]
    return unless message.input_csat?

    response = CsatSurveyResponse.find_by(message: message)
    return unless response

    tracker(message.conversation).record_csat(response: response)
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

  def ownership_service(conversation)
    Captain::Conversation::OwnershipService.new(conversation: conversation)
  end

  def tracker(conversation)
    Captain::ConversationOutcomeTracker.new(conversation: conversation)
  end
end
