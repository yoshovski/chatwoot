class Crm::Hubspot::Mappers::TranscriptNoteMapper
  include Crm::TranscriptFormatting
  include ERB::Util

  # hs_note_body limit: https://developers.hubspot.com/docs/api-reference/crm-notes-v3
  NOTE_MAX_SIZE = 65_536

  def initialize(conversation)
    @conversation = conversation
    @timezone = ActiveSupport::TimeZone['UTC']
  end

  def body
    budget = NOTE_MAX_SIZE - header.length - truncated_notice.length
    lines = []
    # Walk back from the newest message so the cut drops the oldest ones.
    transcript_messages.reverse_each do |message|
      line = format_message(message)
      break if line.length > budget

      budget -= line.length
      lines.unshift(line)
    end
    notice = lines.size < transcript_messages.size ? truncated_notice : ''
    notice + header + lines.join
  end

  private

  def header
    "<p><strong>#{h(I18n.t('crm.hubspot.transcript_title', brand_name: brand_name))}</strong><br>" \
      "#{h(I18n.t('crm.hubspot.transcript_inbox', inbox: @conversation.inbox.name))}<br>" \
      "<a href=\"#{h(conversation_url)}\">#{h(I18n.t('crm.hubspot.view_conversation', display_id: @conversation.display_id))}</a></p>"
  end

  def format_message(message)
    content = h(message_content(message) + attachment_info(message)).gsub("\n", '<br>')
    "<p><strong>#{h(sender_label(message))}</strong> · #{message_time(message)} UTC<br>#{content}</p>"
  end

  def sender_label(message)
    return I18n.t('crm.hubspot.contact') if message.incoming?
    return I18n.t('crm.hubspot.ai_agent') if %w[AgentBot Captain::Assistant].include?(message.sender_type)

    message.sender&.name.presence || I18n.t('crm.hubspot.system')
  end

  def truncated_notice
    @truncated_notice ||= "<p><em>#{h(I18n.t('crm.hubspot.transcript_truncated'))}</em></p>"
  end
end
