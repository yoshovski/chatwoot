# A failed intake stays on this conversation. Never merge contacts using an unverified email.
class Captain::Leads::FailureHandoffService
  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def perform(tool_context, details:)
    @conversation.messages.create!(account: @assistant.account, inbox: @conversation.inbox, sender: @assistant,
                                   message_type: :outgoing, private: true,
                                   content: I18n.t('captain.leads.intake_review', details: details.to_json))
    policy = Captain::Conversation::HandoffPolicy.new(assistant: @assistant, conversation: @conversation)
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
end
