# Emails the visitor a scheduled follow-up from the agent's email template.
class Captain::ScheduledActions::FollowUpEmailHandler
  class NotSent < StandardError; end

  def initialize(action)
    @action = action
  end

  def perform
    result = Captain::ActionEmails.send_to_visitor(@action.conversation, @action.assistant, @action.payload.fetch('template'),
                                                   once_key: "follow_up_#{@action.id}")
    raise NotSent, result.to_s unless result.in?(%i[sent already_sent])
  end
end
