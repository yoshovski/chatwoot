# frozen_string_literal: true

class Captain::Llm::OutcomeClassifierService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  OUTCOMES = %w[
    bot-resolved
    handed-to-human
    no-answer
    purchase-intent
    abandoned
  ].freeze

  SYSTEM_PROMPT = <<~PROMPT.strip.freeze
    You classify the outcome of a customer support conversation for an online store.
    Analyze the transcript and classify it into exactly one of the following outcomes:
    - bot-resolved: The assistant answered the customer's question and resolved their issue without human escalation.
    - handed-to-human: The conversation was escalated or transferred to a human agent.
    - no-answer: The assistant was unable to answer or the customer received no resolution.
    - purchase-intent: The customer expressed clear intent to purchase or buy products.
    - abandoned: The customer left or stopped responding without resolution.

    Reply with ONLY the outcome label name (e.g. bot-resolved), nothing else. No punctuation, no explanation.
  PROMPT

  def initialize(assistant:, conversation:)
    super(feature: 'assistant', account: conversation.account)
    @assistant = assistant
    @conversation = conversation
    @temperature = 0.0
    @max_tokens = 10
  end

  def classify(transcript)
    return nil if transcript.blank?

    response = instrument_llm_call(instrumentation_params(transcript)) do
      chat(model: @model, temperature: @temperature)
        .with_params(max_tokens: @max_tokens)
        .with_instructions(SYSTEM_PROMPT)
        .ask(transcript)
    end

    raw_text = response&.content.to_s.strip.downcase
    OUTCOMES.find { |outcome| raw_text == outcome || raw_text.match?(/\b#{Regexp.escape(outcome)}\b/) }
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @conversation.account).capture_exception
    Rails.logger.warn("[Captain][OutcomeClassifierService] Failed for conversation #{@conversation.display_id}: #{e.class.name}: #{e.message}")
    nil
  end

  private

  def instrumentation_params(transcript)
    {
      span_name: 'llm.captain.outcome_classifier',
      model: @model,
      temperature: @temperature,
      account_id: @conversation.account_id,
      conversation_id: @conversation.display_id,
      feature_name: 'outcome_classifier',
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: transcript }
      ],
      metadata: { assistant_id: @assistant.id }
    }
  end
end
