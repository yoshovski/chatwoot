# Emails the assignee or a team (internal only) with a template and the AI's short summary.
class Captain::Tools::EmailTeamTool < Captain::Tools::BuiltInActionTool
  description 'Emails your team about this conversation (internal, the visitor never sees it)'
  fixed_param :recipient
  fixed_param :template
  param :summary, type: 'string', desc: 'Two or three sentences for the team: who the visitor is and what they need'

  class << self
    include Captain::Tools::TemplateActionHelpers

    def fixed_summary(assistant, params)
      "emails #{recipient_label(assistant, params['recipient'])} \"#{template_name(assistant, params['template'])}\""
    end

    def team(assistant, recipient) = assistant.account.teams.find_by(id: recipient.to_s.delete_prefix('team:'))

    private

    def recipient_label(assistant, recipient)
      recipient == 'assignee' ? 'the assignee' : "the #{team(assistant, recipient)&.name || 'team'} team"
    end

    def validate_fixed_params(assistant, params)
      recipient = params['recipient'].to_s
      valid_recipient = recipient == 'assignee' || (recipient.match?(/\Ateam:\d+\z/) && team(assistant, recipient))
      (valid_recipient ? [] : ["no recipient #{recipient}"]) + template_errors(assistant, params['template'])
    end
  end

  def perform(tool_context, summary:)
    state = tool_context.state
    error = fixed_params_error(state)
    return error if error
    return 'Would email the team (preview, nothing sent).' if state[:source] == 'playground'

    conversation = find_conversation(state)
    return failure_result('Conversation not found', state) unless conversation

    result = Captain::ActionEmails.send_to_team(conversation, @assistant, recipient: fixed(:recipient), template_key: fixed(:template),
                                                                          summary: summary)
    log_tool_usage('email_team', conversation_id: conversation.id, recipient: fixed(:recipient), result: result)
    return 'The team was emailed. Keep helping; this is not a handoff.' if result == :sent

    failure_result("The team email wasn't sent (#{result.to_s.humanize(capitalize: false)}). Don't say it was.", state)
  end
end
