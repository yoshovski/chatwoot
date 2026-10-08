class Captain::Conversation::HandoffNoteService
  include Integrations::LlmInstrumentation

  NOTE_HEADER = '🔔 **Needs your reply**'.freeze
  FALLBACK_NOTE = 'Summary unavailable, read the thread above.'.freeze
  DEFAULT_MODEL = 'llm-fast'.freeze
  TEMPERATURE = 0.2
  MAX_TOKENS = 200
  TIMEOUT_SECONDS = 10
  MAX_TRANSCRIPT_CHARS = 6000
  MAX_TRANSCRIPT_MESSAGES = 40

  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.strip.freeze
    You write the short internal note a colleague leaves when handing a live chat to someone else. Input is a transcript between a customer and an online store's support assistant.

    Reply in exactly this shape, one line each, no other text:

    Wants: <what they asked for>
    Details: <model, variant, order number, budget, timeline - only what they actually said>
    Next: <the single next action for the team>

    Rules:
    - Focus on the latest unresolved customer request. Do not revive earlier questions that were already answered or declined.
    - Maximum 12 words per line. Fragments, not sentences.
    - Omit the Details line entirely if they gave no specifics. Never write "none" or "not specified".
    - Only facts stated in the transcript. Never infer, never pad.
    - No email address, no phone number.
    - No greeting, no preamble, no sign-off, no bullet characters.
  PROMPT

  attr_reader :conversation, :assistant, :reason

  def initialize(conversation:, assistant: nil, reason: nil)
    @conversation = conversation
    @assistant = assistant || conversation&.inbox&.captain_assistant
    @reason = reason
  end

  def post_note!(content = generate_note_content)
    return nil if conversation.blank?

    sender = assistant || conversation.inbox&.captain_assistant

    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: sender,
      account: conversation.account,
      inbox: conversation.inbox,
      content: content
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation&.account).capture_exception
    Rails.logger.error("[Captain][HandoffNoteService] Failed to post note: #{e.class}: #{e.message}")
    nil
  end

  def generate_note_content
    return "#{NOTE_HEADER}\n#{reason}" if reason.present?

    summary = generate_summary
    "#{NOTE_HEADER}\n#{summary}"
  end

  def generate_summary
    return FALLBACK_NOTE unless captain_responses_left?

    transcript = build_transcript
    return FALLBACK_NOTE if transcript.blank?

    summary = request_summary(transcript)
    summary = sanitize_summary(summary) if summary.present?
    summary.presence || FALLBACK_NOTE
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation&.account).capture_exception
    Rails.logger.warn("[Captain][HandoffNoteService] Failed to generate summary: #{e.class}: #{e.message}")
    FALLBACK_NOTE
  end

  def build_transcript
    return '' if conversation.blank?

    messages = conversation.messages
                           .where(private: false)
                           .where(message_type: [:incoming, :outgoing])
                           .order(created_at: :desc)
                           .limit(MAX_TRANSCRIPT_MESSAGES)
                           .reverse

    lines = messages.filter_map { |m| format_message_line(m) }
    transcript = lines.join("\n")

    if transcript.length > MAX_TRANSCRIPT_CHARS
      transcript.slice(-MAX_TRANSCRIPT_CHARS..-1)
    else
      transcript
    end
  end

  private

  # A handoff because the account ran out of Captain responses gets no LLM summary either.
  def captain_responses_left?
    conversation.account.usage_limits[:captain][:responses][:current_available].positive?
  end

  def request_summary(transcript)
    summary = call_llm(model: configured_model, prompt: system_prompt, input: transcript)
    return summary if summary.present?
    return nil unless fallback_model_needed?

    call_llm(model: fallback_installation_model, prompt: system_prompt, input: transcript)
  end

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

  def system_prompt
    conversation.account&.custom_attributes&.dig('captain_handoff_summary_prompt').presence || DEFAULT_SYSTEM_PROMPT
  end

  def configured_model
    conversation.account&.custom_attributes&.dig('captain_handoff_summary_model').presence || DEFAULT_MODEL
  end

  def fallback_installation_model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence
  end

  def fallback_model_needed?
    fallback = fallback_installation_model
    fallback.present? && fallback != configured_model
  end

  def sanitize_summary(summary)
    summary.to_s.sub(/\A🔔\s*\*\*Needs your reply\*\*\s*\n?/i, '').strip
  end

  def call_llm(model:, prompt:, input:)
    response = instrument_llm_call(instrumentation_params(model, prompt, input)) do
      llm_context.chat(model: model, provider: :openai, assume_model_exists: true)
                 .with_temperature(TEMPERATURE)
                 .with_params(max_tokens: MAX_TOKENS)
                 .with_instructions(prompt)
                 .ask(input)
    end
    response.content.to_s.strip.presence
  rescue RubyLLM::Error, Faraday::Error => e
    Rails.logger.warn("[Captain][HandoffNoteService] LLM call error (#{model}): #{e.class}: #{e.message}")
    nil
  end

  # Captain's LLM endpoint and key, with a short timeout and no retries: the fallback model is the retry.
  def llm_context
    Llm::Config.initialize!
    RubyLLM.context do |config|
      config.request_timeout = TIMEOUT_SECONDS
      config.max_retries = 0
    end
  end

  def instrumentation_params(model, prompt, input)
    {
      span_name: 'llm.captain.handoff_summary',
      model: model,
      temperature: TEMPERATURE,
      account_id: conversation.account_id,
      conversation_id: conversation.display_id,
      feature_name: 'handoff_summary',
      messages: [{ role: 'system', content: prompt }, { role: 'user', content: input }],
      metadata: { assistant_id: assistant&.id }
    }
  end
end
