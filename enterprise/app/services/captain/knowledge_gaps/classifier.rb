# One call to the fast model (the intent router's model) that turns a raw customer message into a gap the store can
# act on: what kind it is, one short general question without personal details, a topic and the language.
# Runs in a background job and is never counted as AI usage: it calls the model directly and records nothing.
class Captain::KnowledgeGaps::Classifier
  class InvalidOutput < StandardError; end

  Result = Struct.new(:kind, :question, :topic, :language, :intent, keyword_init: true)

  CONTEXT_MESSAGES = 6
  CONTEXT_CHARS = 300
  TOPIC_LIMIT = 30
  TIMEOUT_SECONDS = 20

  PROMPT = <<~PROMPT.freeze
    You sort messages that an online store's AI assistant could not answer, so the store owner sees a short list of
    general questions worth answering. You get the customer's message, the few messages before it, and the topics the
    store already has. Reply with one JSON object:
    {"kind": "...", "canonical_question": "...", "topic": "...", "language": "...", "intent": "..."}

    kind, exactly one of:
    - knowledge: a question about the store, its products, policies, shipping, compatibility or usage that a written
      answer in the store's knowledge would solve for every customer who asks it.
    - action_request: the customer wants something done or looked up for them: where is my order, cancel, return or
      refund an order, change an address, book or reschedule something.
    - personal: about this customer only and not an action (a complaint about their own case, account details).
    - off_topic: greetings, thanks, spam, jokes, messages unrelated to the store.

    canonical_question: for knowledge, one short general question as the store owner would write it in an FAQ, in
    the customer's language, with no names, order numbers, emails, phone numbers or personal story. Keep the product
    or model names that matter. For other kinds, a short neutral summary of the request, also without personal details.

    topic: two or three words naming the subject (for example "Shipping costs", "Generator compatibility",
    "Order status"). Reuse an existing topic when it fits; otherwise make a new one in the customer's language.

    language: ISO 639-1 code of the customer's message.

    intent: only for action_request, one of order_status, cancel, return, booking, other. Otherwise null.

    Example: "I have a dji t50 and the generator I bought doesn't keep up, want to make sure the generator you are
    selling will" -> {"kind": "knowledge", "canonical_question": "Can your generator power a DJI T50?",
    "topic": "Generator compatibility", "language": "en", "intent": null}
    Example: "can you check where is my order" -> {"kind": "action_request", "canonical_question": "Where is my order?",
    "topic": "Order status", "language": "en", "intent": "order_status"}
  PROMPT

  def self.for_gap(gap)
    occurrence = gap.occurrences.order(created_at: :desc).first
    new(account_id: gap.account_id, message: occurrence&.question.presence || gap.question,
        earlier_messages: earlier_messages(occurrence), existing_topics: existing_topics(gap))
  end

  # The few public messages before the customer's question, so "and in red?" can be understood.
  def self.earlier_messages(occurrence)
    return [] unless occurrence&.message_id

    occurrence.conversation.messages.where(private: false, message_type: %i[incoming outgoing])
              .where(id: ...occurrence.message_id).reorder(id: :desc).limit(CONTEXT_MESSAGES).reverse
              .map { |message| { role: message.incoming? ? 'customer' : 'store', text: message.content.to_s.truncate(CONTEXT_CHARS) } }
  end

  def self.existing_topics(gap)
    gap.assistant.knowledge_gaps.where.not(topic: nil).where.not(id: gap.id)
       .group(:topic).order(Arel.sql('COUNT(*) DESC')).limit(TOPIC_LIMIT).pluck(:topic)
  end

  def initialize(account_id:, message:, earlier_messages: [], existing_topics: [])
    @account_id = account_id
    @input = { message: message, earlier_messages: earlier_messages, existing_topics: existing_topics }
  end

  def classify
    response = chat.ask(@input.to_json)
    parse(response.content.is_a?(Hash) ? response.content : JSON.parse(response.content.to_s))
  rescue JSON::ParserError => e
    raise InvalidOutput, e.message
  end

  private

  def chat
    Captain::Assistant::TieredLlmClient.chat(account_id: @account_id, model: ENV.fetch('CAPTAIN_INTENT_ROUTER_MODEL', 'intent-router'),
                                             timeout: TIMEOUT_SECONDS)
                                       .with_params(max_tokens: 300, response_format: { type: 'json_object' })
                                       .with_instructions(PROMPT)
  end

  def parse(output)
    kind = output['kind'].to_s
    question = output['canonical_question'].to_s.squish
    raise InvalidOutput, "kind #{kind.inspect}" unless Captain::KnowledgeGap.kinds.except('unclassified').key?(kind)
    raise InvalidOutput, 'empty canonical_question' if question.blank?

    Result.new(kind: kind, question: question.truncate(Captain::KnowledgeGap::QUESTION_LIMIT), topic: text(output['topic'], 120),
               language: text(output['language'], 10)&.downcase, intent: intent(kind, output['intent']))
  end

  def text(value, limit)
    value.to_s.squish.first(limit).presence
  end

  def intent(kind, value)
    return unless kind == 'action_request'

    Captain::KnowledgeGap::INTENTS.include?(value.to_s) ? value.to_s : 'other'
  end
end
