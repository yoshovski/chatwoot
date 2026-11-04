# Emails the visitor one of the agent's email templates, once per template per conversation.
class Captain::Tools::EmailVisitorTool < Captain::Tools::BuiltInActionTool
  description 'Emails the visitor a prepared message'
  fixed_param :template

  RESULTS = {
    sent: 'Email sent to the visitor.',
    already_sent: 'This email was already sent in this conversation. Do not send it again.',
    no_email: "No email address for the visitor yet. Ask for it, save it, then try again. Don't say it was sent.",
    rate_limited: "The email couldn't be sent today. Don't say it was sent; offer to help here instead."
  }.freeze

  class << self
    include Captain::Tools::TemplateActionHelpers

    def fixed_summary(assistant, params) = "emails the visitor \"#{template_name(assistant, params['template'])}\""

    private

    def validate_fixed_params(assistant, params) = template_errors(assistant, params['template'])
  end

  def perform(tool_context)
    state = tool_context.state
    error = fixed_params_error(state)
    return error if error
    return 'Would email the visitor (preview, nothing sent).' if state[:source] == 'playground'

    conversation = find_conversation(state)
    return failure_result('Conversation not found', state) unless conversation
    return failure_result('This conversation is already by email: answer in your reply instead.', state) if conversation.inbox.email?

    result = Captain::ActionEmails.send_to_visitor(conversation, @assistant, fixed(:template))
    log_tool_usage('email_visitor', conversation_id: conversation.id, template: fixed(:template), result: result)
    result == :sent ? RESULTS[:sent] : failure_result(RESULTS.fetch(result), state)
  end
end
