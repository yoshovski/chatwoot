module Captain::Assistant::LocalizedResponse
  private

  def enforce_reply_locale(run_result)
    policy = Captain::Conversation::CustomerLocale
    locale = run_result.context&.dig(:state, policy::STATE_KEY)
    return unless locale

    output = run_result.output.with_indifferent_access
    parts = Captain::Assistant::ResponseParts.from_response(output)
    output = translate_reply(run_result, parts, locale) if policy.mismatch?(parts.plain_text, locale)
    remove_wrong_language_extras(output, locale)
    run_result.output = output
  end

  def remove_wrong_language_extras(output, locale)
    policy = Captain::Conversation::CustomerLocale
    output.delete('welcome') if policy.mismatch?(output['welcome'], locale)
    follow_up = output['follow_up']
    output.delete('follow_up') if follow_up.is_a?(Hash) && policy.mismatch?(follow_up['text'], locale)
    suggestions = Array(output['suggested_replies']).flat_map { |item| item.is_a?(Hash) ? item.values : item }
    output['suggested_replies'] = [] if policy.mismatch?(suggestions.join(' '), locale)
  end

  def translate_reply(run_result, parts, locale)
    output = response_rewriter.rewrite(run_result, response_parts: parts, locale: locale).output
    return output unless Captain::Conversation::CustomerLocale.mismatch?(Captain::Assistant::ResponseParts.from_response(output).plain_text, locale)

    localized_reply_failure(run_result, locale)
  rescue StandardError => e
    Rails.logger.warn "[Captain][ReplyLocale] translation_failed assistant_id=#{@assistant.id} error=#{e.class.name}"
    localized_reply_failure(run_result, locale)
  end

  def localized_reply_failure(run_result, locale)
    text = Captain::Conversation::CustomerLocale.available_text('captain.reply_languages.retry', locale: locale, assistant: @assistant)
    run_result.context[:state][:reply_language_unavailable] = true unless text
    run_result.output.with_indifferent_access.except('welcome', 'follow_up', 'suggested_replies').merge(
      'response_parts' => [{ 'text' => text.to_s, 'citation_indexes' => [] }], 'response' => text.to_s
    )
  end
end
