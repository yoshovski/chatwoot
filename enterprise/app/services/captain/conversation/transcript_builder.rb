# frozen_string_literal: true

class Captain::Conversation::TranscriptBuilder
  MAX_TRANSCRIPT_CHARS = 6000
  MAX_TRANSCRIPT_MESSAGES = 40

  attr_reader :conversation, :max_messages, :max_chars

  def initialize(conversation, max_messages: MAX_TRANSCRIPT_MESSAGES, max_chars: MAX_TRANSCRIPT_CHARS)
    @conversation = conversation
    @max_messages = max_messages
    @max_chars = max_chars
  end

  def build
    return '' if conversation.blank?

    messages = conversation.messages
                           .where(private: false)
                           .where(message_type: [:incoming, :outgoing])
                           .order(created_at: :desc)
                           .limit(max_messages)
                           .reverse

    lines = messages.filter_map { |m| format_message_line(m) }
    transcript = lines.join("\n")

    if transcript.length > max_chars
      transcript.slice(-max_chars..-1)
    else
      transcript
    end
  end

  private

  def format_message_line(message)
    role = message.incoming? ? 'Customer' : 'Assistant'
    text = message.content.to_s.strip

    submitted = extract_submitted_values(message)
    text = text.present? ? "#{text} (Submitted: #{submitted})" : "(Submitted: #{submitted})" if submitted.present?

    return nil if text.blank?

    "#{role}: #{text}"
  end

  def extract_submitted_values(message)
    sv = message.content_attributes&.dig('submitted_values')
    return nil if sv.blank?

    if sv.is_a?(Array)
      format_submitted_array(sv)
    elsif sv.is_a?(Hash)
      format_submitted_hash(sv)
    else
      sv.to_s
    end
  end

  def format_submitted_array(values)
    values.filter_map do |item|
      if item.is_a?(Hash)
        item['title'].presence || item['value'].presence || item['name'].presence || item.to_s
      else
        item.to_s
      end
    end.join(', ')
  end

  def format_submitted_hash(values)
    values.map { |k, v| "#{k}: #{v}" }.join(', ')
  end
end
