# Decides what the customer sees for one Captain V2 run: the answer (prose, citations, suggestion buttons or the
# empty-answer fallback), the order card and the product cards. With cards, one suggestion group (with any closing
# question) appears after all cards. Returns message payloads and writes nothing; Captain::Reply::Builder does the work.
class Captain::Conversation::ReplyComposer
  attr_reader :assistant, :conversation, :response, :run_result, :customer_message

  def initialize(assistant:, response:, run_result:, conversation: nil, customer_message: nil)
    @assistant = assistant
    @conversation = conversation
    @response = response
    @run_result = run_result
    @customer_message = customer_message
  end

  # suppress_suggestions: the caller knows the run ends in a handoff (or the conversation already waits for a human).
  # segment_kinds: true adds captain_segment_kinds, which the chat job stores with each message.
  def messages(suppress_suggestions: false, segment_kinds: false)
    plan(suppress_suggestions: suppress_suggestions).payloads(segment_kinds: segment_kinds)
  end

  def plan(suppress_suggestions: false)
    Captain::Reply::Builder.build(context(suppress_suggestions), draft)
  end

  def empty_response?
    Captain::Reply::Builder.empty_answer?(context(false), draft)
  end

  private

  def context(suppress_suggestions)
    Captain::Reply::Context.build(assistant: assistant, conversation: conversation, run_result: run_result,
                                  customer_message: customer_message, suppress_suggestions: suppress_suggestions)
  end

  def draft
    @draft ||= Captain::Reply::Draft.from_response(response)
  end
end
