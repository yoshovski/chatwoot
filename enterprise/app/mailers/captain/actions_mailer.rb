# Emails sent by the AI agent's built-in actions (email_visitor, email_team, email follow-ups) from the agent's email
# templates: plain text, plus an HTML part when the template is HTML.
class Captain::ActionsMailer < ApplicationMailer
  # SMTP errors reach the job so delivery can be retried rather than reported as sent.
  rescue_from(*ExceptionList::SMTP_EXCEPTIONS) { |error| raise error }

  def visitor_email(conversation, subject, body, html = nil)
    from = Mail::Address.new(self.class.default[:from])
    from.display_name = conversation.inbox.name
    mail(to: conversation.contact.email, from: from.to_s, subject: subject) { |format| formats(format, body, html) }
  end

  def team_email(conversation, recipients, subject, body, html = nil)
    url = app_account_conversation_url(account_id: conversation.account_id, id: conversation.display_id)
    link = %(<p><a href="#{ERB::Util.html_escape(url)}">#{ERB::Util.html_escape(url)}</a></p>)
    mail(to: recipients, subject: subject) { |format| formats(format, "#{body}\n\n#{url}", html && "#{html}#{link}") }
  end

  private

  def formats(format, text, html)
    format.text { render plain: text }
    format.html { render html: html.html_safe } if html # rubocop:disable Rails/OutputSafety
  end
end
