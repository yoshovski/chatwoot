# Sent once in a widget conversation started while the account is over its plan's conversation limit (Free). The
# message is kept; the visitor learns the team answers by email and, without an email on file, gets the email box.
class MessageTemplates::Template::OverConversationsLimit
  pattr_initialize [:conversation!]

  def perform
    conversation.reload.with_lock do
      next if conversation.messages.template.exists?

      conversation.messages.create!(template_params(I18n.t('conversations.templates.over_conversations_limit_message_body')))
      next if conversation.contact.email.present?

      conversation.messages.create!(template_params(I18n.t('conversations.templates.email_input_box_message_body',
                                                           account_name: conversation.account.name)).merge(content_type: :input_email))
    end
  end

  private

  def template_params(content)
    { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :template, content: content }
  end
end
