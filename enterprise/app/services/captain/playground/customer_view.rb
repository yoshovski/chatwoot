# What the customer would see for one playground run: the same message payloads the chat job would post, built
# without a conversation, plus the handoff the run asked for. Nothing is written.
class Captain::Playground::CustomerView
  FORM_FIELDS = %w[name email].freeze

  def initialize(assistant:, response:, run_result:, message_history:, handoff_reason: nil)
    @assistant = assistant
    @response = response
    @run_result = run_result
    @customer_message = message_history.reverse.find { |message| message[:role].to_s == 'user' }&.dig(:content).to_s
    @handoff_reason = handoff_reason
  end

  def to_h
    composer = Captain::Conversation::ReplyComposer.new(
      assistant: @assistant, response: @response, run_result: @run_result, customer_message: @customer_message
    )
    source = Captain::Conversation::HandoffDetector.new(
      assistant: @assistant, response: @response, customer_message: @customer_message, composer: composer
    ).source
    messages = composer.messages(suppress_suggestions: source.present?)
    return { messages: messages, handoff: nil } unless source

    messages << Captain::Conversation::ContactCaptureService.form_payload(FORM_FIELDS)
    { messages: messages, handoff: { source: source, reason: @handoff_reason } }
  end
end
