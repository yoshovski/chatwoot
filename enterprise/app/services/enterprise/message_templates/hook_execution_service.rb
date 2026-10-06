module Enterprise::MessageTemplates::HookExecutionService
  def trigger_templates
    super
    return unless captain_conversation_message?

    # Eligibility is demand-level: every inbound customer message in a
    # Captain-connected inbox counts, including conversations a human grabbed
    # first or that arrive while the account is over its usage limit —
    # otherwise the coverage denominator only ever contains conversations
    # Captain was already about to answer.
    track_captain_eligibility
    return unless captain_may_reply?
    return perform_handoff unless inbox.captain_active?

    Captain::Conversation::ResponseSchedulerService.new(message: message).perform
  end

  def should_send_greeting?
    return false if captain_handling_conversation?

    super
  end

  def should_send_out_of_office_message?
    return false if captain_handling_conversation?

    super
  end

  def should_send_email_collect?
    return false if captain_handling_conversation?

    super
  end

  private

  def track_captain_eligibility
    return unless conversation.account.feature_enabled?('captain_integration_v2')

    Captain::ConversationOutcomeTracker.new(
      conversation: conversation,
      assistant: inbox.captain_assistant
    ).record_eligibility(at: message.created_at)
  end

  def captain_conversation_message?
    message.captain_response_triggering? && captain_assistant_configured? && !inbox.external_bot_active?
  end

  def perform_handoff
    handoff_service = Captain::Conversation::HandoffService.new(
      conversation: conversation,
      assistant: inbox.captain_assistant
    )
    return if handoff_service.handoff_active?

    Rails.logger.info("Captain limit exceeded, performing handoff mid-conversation for conversation: #{conversation.id}")
    create_usage_limit_transfer_message
    conversation.bot_handoff!
    handoff_service.apply_extras!
    emit_usage_limit_handoff_event
    send_out_of_office_message_after_handoff
  end

  def create_usage_limit_transfer_message
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account.id,
      inbox_id: conversation.inbox.id,
      content: 'Transferring to another agent for further assistance.'
    )
  end

  def emit_usage_limit_handoff_event
    Captain::ConversationEvents.handed_off(
      conversation: conversation,
      assistant: inbox.captain_assistant,
      source: Captain::ConversationEvents::Sources::USAGE_LIMIT,
      reason_category: :usage_limit,
      at: Time.current
    )
  end

  def send_out_of_office_message_after_handoff
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def captain_handling_conversation?
    captain_may_reply?
  end

  def captain_may_reply?
    return false unless captain_assistant_configured?

    Captain::Conversation::OwnershipService.new(
      conversation: conversation,
      assistant: inbox.captain_assistant
    ).may_reply?
  end

  def captain_assistant_configured?
    inbox.captain_assistant.present?
  end
end
