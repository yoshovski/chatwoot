class Captain::Conversation::HandoffService
  attr_reader :conversation, :assistant, :reason

  def initialize(conversation:, assistant: nil, reason: nil)
    @conversation = conversation
    @assistant = assistant || conversation&.inbox&.captain_assistant
    @reason = reason
  end

  def ownership_service
    @ownership_service ||= Captain::Conversation::OwnershipService.new(
      conversation: conversation,
      assistant: assistant
    )
  end

  def handoff_active?
    return true if ownership_service.needs_human_label?
    return true if ownership_service.waiting?

    false
  end

  # The summary may take an LLM call. Build it before taking the conversation lock, so the customer's
  # next message doesn't wait on it; callers holding their own lock call this before locking.
  def note_content
    @note_content ||= note_service.generate_note_content
  end

  def apply_extras!(lock: true)
    return nil if conversation.blank?
    return nil if handoff_active?

    note_content
    if lock
      conversation.with_lock do
        return nil if handoff_active?

        persist_extras!
      end
    else
      persist_extras!
    end
  end

  def trigger_contact_capture_form!(triggering_message: nil)
    return nil if conversation.blank?

    contact_capture_service.post_form_if_needed!(triggering_message: triggering_message)
  end

  def contact_capture_service
    @contact_capture_service ||= Captain::Conversation::ContactCaptureService.new(
      conversation: conversation,
      assistant: assistant
    )
  end

  private

  def persist_extras!
    ownership_service.add_needs_human_label!
    note_service.post_note!(note_content)
  end

  def note_service
    @note_service ||= Captain::Conversation::HandoffNoteService.new(
      conversation: conversation,
      assistant: assistant,
      reason: reason
    )
  end
end
