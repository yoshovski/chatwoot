# The answer bubble: the prose with its citations, sources, offering links, knowledge media and grounded screenshots.
# When nothing usable remains, a fallback says why (empty catalog search, only attachments, unusable answer, handoff).
class Captain::Reply::Policies::Answer < Captain::Reply::Policies::Base
  def self.empty?(workspace) = new(workspace).empty?

  def apply
    workspace.segments = [answer_segment]
  end

  def empty?
    workspace.formatted_prose.blank? && !catalog_searches_empty? && !customer_message_has_attachments? && !model_returned_answer?
  end

  private

  def answer_segment
    sources = workspace.structured_sources
    return workspace.answer_segment(workspace.answer_parts, sources: sources) if workspace.formatted_prose.present?

    text = fallback_text
    workspace.answer_segment([Captain::Reply::Part.new(text: text, kind: :fallback)], sources: sources, text: text)
  end

  def fallback_text
    key = if catalog_searches_empty?
            'empty_response_catalog_empty'
          elsif customer_message_has_attachments?
            'empty_response_attachments'
          elsif model_returned_answer?
            'empty_response_unusable'
          else
            'empty_response_handoff'
          end
    Captain::Conversation::CustomerLocale.translate("conversations.captain.#{key}",
                                                    locale: context.reply_locale || assistant.account.locale, assistant: assistant)
  end

  def catalog_searches_empty?
    stats = assistant.run_result_product_search_stats(run_result)
    return false if stats.blank?

    stats[:searches].positive? && stats[:results].zero?
  end

  def customer_message_has_attachments?
    customer_message = context.customer_message
    customer_message.respond_to?(:attachments) && customer_message.attachments.any?
  end

  def model_returned_answer?
    response = draft.raw
    raw_response = response.is_a?(Hash) ? (response['response'] || response[:response]) : response.to_s
    raw_response.to_s.strip.present? || Captain::Assistant::ResponseParts.from_response(response).plain_text.strip.present?
  end
end
