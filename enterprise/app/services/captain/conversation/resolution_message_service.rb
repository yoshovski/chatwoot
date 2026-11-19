class Captain::Conversation::ResolutionMessageService
  pattr_initialize [:conversation!, :assistant!]

  def perform(use_default_message: false)
    return unless assistant.send_inactivity_resolution_message?

    policy = Captain::Conversation::CustomerLocale
    locale = policy.resolve(conversation: conversation, assistant: assistant)
    resolution_message = Captain::LocalizedMessages.new(assistant.config).text('resolution_message', locale)
    if use_default_message
      resolution_message ||= policy.translate('conversations.activity.auto_resolution_message', locale: locale, assistant: assistant)
    end
    return if resolution_message.blank?

    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: resolution_message,
      sender: assistant
    )
  end
end
