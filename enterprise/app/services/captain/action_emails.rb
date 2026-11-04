# Sends the emails of the AI agent's built-in actions from the agent's email templates. Each visitor email is sent once
# per conversation and key, within the account's daily email limit.
module Captain::ActionEmails
  SENT_ATTRIBUTE = 'captain_emails_sent'.freeze
  SUMMARY_LIMIT = 1000

  module_function

  # Returns :sent, :no_email, :already_sent or :rate_limited.
  def send_to_visitor(conversation, assistant, template_key, once_key: template_key)
    return :no_email if conversation.contact&.email.blank?
    return :rate_limited unless conversation.account.within_email_rate_limit?
    return :already_sent unless claim_once(conversation, once_key.to_s)

    email = Captain::EmailTemplates.new(assistant).render(template_key, conversation)
    Captain::ActionsMailer.visitor_email(conversation, email[:subject], email[:body]).deliver_later
    conversation.account.increment_email_sent_count
    :sent
  end

  # recipient: 'assignee' or 'team:<id>'. Returns :sent, :no_recipients or :rate_limited.
  def send_to_team(conversation, assistant, recipient:, template_key:, summary:)
    emails = recipient_emails(conversation, recipient)
    return :no_recipients if emails.empty?
    return :rate_limited unless conversation.account.within_email_rate_limit?

    email = Captain::EmailTemplates.new(assistant).render(template_key, conversation, summary: summary.to_s.truncate(SUMMARY_LIMIT))
    Captain::ActionsMailer.team_email(conversation, emails, email[:subject], email[:body]).deliver_later
    conversation.account.increment_email_sent_count
    :sent
  end

  def recipient_emails(conversation, recipient)
    users = if recipient == 'assignee'
              Array(conversation.assignee)
            else
              conversation.account.teams.find_by(id: recipient.to_s.delete_prefix('team:'))&.members.to_a
            end
    users.filter_map { |user| user.email if user.confirmed? }.uniq
  end

  def claim_once(conversation, key)
    ::Conversation.transaction do
      locked = ::Conversation.lock.find(conversation.id)
      sent = Array(locked.additional_attributes&.dig(SENT_ATTRIBUTE))
      next false if sent.include?(key)

      locked.update_columns(additional_attributes: (locked.additional_attributes || {}).merge(SENT_ATTRIBUTE => sent + [key])) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
