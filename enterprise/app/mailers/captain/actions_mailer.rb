# Emails sent by the AI agent's built-in actions (email_visitor, email_team, email follow-ups). Plain text from the
# agent's email templates.
class Captain::ActionsMailer < ApplicationMailer
  # SMTP errors reach the job so delivery can be retried rather than reported as sent.
  rescue_from(*ExceptionList::SMTP_EXCEPTIONS) { |error| raise error }

  def visitor_email(conversation, subject, body)
    from = Mail::Address.new(self.class.default[:from])
    from.display_name = conversation.inbox.name
    mail(to: conversation.contact.email, from: from.to_s, subject: subject) { |format| format.text { render plain: body } }
  end

  def team_email(conversation, recipients, subject, body)
    url = app_account_conversation_url(account_id: conversation.account_id, id: conversation.display_id)
    mail(to: recipients, subject: subject) { |format| format.text { render plain: "#{body}\n\n#{url}" } }
  end
end
