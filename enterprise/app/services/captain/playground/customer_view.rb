# What the customer would see for one playground run: the same message payloads the chat job would post, built
# without a conversation, plus the handoff the run asked for and the sources the reply used. Nothing is written.
class Captain::Playground::CustomerView
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
    return { messages: messages, handoff: nil, sources: used_sources } unless source

    capture = Captain::Conversation::ContactCaptureService
    locale = @run_result&.context&.dig(:state, Captain::Conversation::CustomerLocale::STATE_KEY) ||
             Captain::Conversation::CustomerLocale.resolve(assistant: @assistant, customer_message: @customer_message)
    messages << capture.form_payload(capture.requested_fields(@assistant), assistant: @assistant, locale: locale)
    { messages: messages, handoff: { source: source, reason: @handoff_reason }, sources: used_sources }
  end

  private

  def used_sources
    Captain::Assistant::RunSources.new(@run_result).to_a.select { |source| source[:used] }
                                  .map { |source| source.slice(:kind, :title, :url, :document_title) }
  end
end
