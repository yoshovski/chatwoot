# A failed intake stays on this conversation. Never merge contacts using an unverified email.
class Captain::Leads::FailureHandoffService
  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def perform(tool_context, details:)
    post_review_note(details)
    locale = tool_context.state[Captain::Conversation::CustomerLocale::STATE_KEY]
    policy = Captain::Conversation::HandoffPolicy.new(assistant: @assistant, conversation: @conversation, locale: locale)
    if policy.keep?
      tool_context.state[:lead_capture_recovery_message] = policy.keep_message
      return policy.keep_message
    end

    tool_context.state[:lead_intake_needs_review] = true
    result = Captain::Tools::HandoffTool.new(@assistant).execute(
      tool_context, reason: 'Business follow-up intake needs team review. Customer-provided details are in the private note.',
                    reason_category: 'tool_failure'
    )
    tool_context.state[:lead_failure_handoff] = tool_context.state[:captain_v2_handoff_tool_completed] == true
    tool_context.state[:lead_capture_recovery_message] = policy.handoff_message if tool_context.state[:lead_failure_handoff]
    result
  end

  private

  def post_review_note(details)
    @conversation.messages.create!(account: @assistant.account, inbox: @conversation.inbox, sender: @assistant,
                                   message_type: :outgoing, private: true,
                                   content: I18n.t('captain.leads.intake_review', details: details.to_json))
  end
end
