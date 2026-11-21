class MessageTemplates::Template::OutOfOffice
  pattr_initialize [:conversation!, :locale]

  def self.perform_if_applicable(conversation, locale: nil)
    inbox = conversation.inbox
    return unless inbox.out_of_office? && inbox.out_of_office_message_configured?

    new(conversation: conversation, locale: locale).perform
  end

  def perform
    content = conversation.inbox.out_of_office_message_for(reply_locale)
    return if content.blank?

    ActiveRecord::Base.transaction do
      conversation.messages.create!(out_of_office_message_params(content))
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    true
  end

  private

  delegate :contact, :account, to: :conversation
  delegate :inbox, to: :message

  def reply_locale
    locale.presence || conversation.additional_attributes.dig('captain_reply_locale', 'locale').presence ||
      conversation.contact_inbox&.website_activity&.dig('browser_language').presence ||
      conversation.additional_attributes['browser_language'].presence || account.locale
  end

  def out_of_office_message_params(content)
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: content
    }
  end
end
