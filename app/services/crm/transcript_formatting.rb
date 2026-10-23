# Message selection and formatting shared by CRM transcript exports.
# Including classes set @conversation and @timezone.
module Crm::TranscriptFormatting
  extend ActiveSupport::Concern

  included do
    include ::Rails.application.routes.url_helpers
  end

  private

  def transcript_messages
    @transcript_messages ||= @conversation.messages.chat.select(&:conversation_transcriptable?)
  end

  def message_time(message)
    message.created_at.in_time_zone(@timezone).strftime('%Y-%m-%d %H:%M')
  end

  def message_content(message)
    message.content.presence || I18n.t('crm.no_content')
  end

  def attachment_info(message)
    return '' unless message.attachments.any?

    attachments = message.attachments.map { |a| I18n.t('crm.attachment', type: a.file_type) }.join(', ')
    "\n#{attachments}"
  end

  def conversation_url
    app_account_conversation_url(account_id: @conversation.account.id, id: @conversation.display_id)
  end

  def brand_name
    ::GlobalConfig.get('BRAND_NAME')['BRAND_NAME'] || 'Chatwoot'
  end
end
