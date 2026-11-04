# Reads from one V2 run whether the customer is being handed to a colleague. The chat job acts on it (and adds the
# conversation state checks); the playground only reports it.
class Captain::Conversation::HandoffDetector
  EMPTY_RESPONSE = 'empty_response'.freeze
  # A reply that says a colleague will reply or continue declares the handoff even when the model left handoff_requested
  # false (see Captain::ResponseSchema::HANDOFF_REQUESTED_DESCRIPTION), so that promise is always kept. Only a person in
  # this chat counts: "the team can follow up by email" (the lead follow-up) and offers or conditions don't.
  COLLEAGUE_PROMISE = /
    \b(?:colleagues?|teammates?|team\s+members?|members?\s+of\s+(?:our|the)\s+(?:\w+\s+)?team|someone\s+from\s+(?:our|the)\s+(?:\w+\s+)?team|
       specialists?|representatives?|(?:human|live|support)\s+agents?)\b
    [^.!?\n]{0,40}?\b(?:will|'ll|is\s+going\s+to)\s+(?:\w+\s+)?
    (?:reply|respond|continue(?!\s+to\b)|take\s+over|get\s+back\s+to\s+you|be\s+with\s+you|join)\b
  /ix
  NOT_A_PROMISE = /\b(?:if|once|would|could|e-?mail)\b|\?\s*\z/i

  def self.tool_fired?(response) = response['handoff_tool_called']

  def self.declared?(response) = response['handoff_requested'] == true || colleague_promised?(response)

  def self.colleague_promised?(response)
    return false unless response.key?('response_parts')

    Captain::Assistant::ResponseParts.from_response(response).plain_text.split(/(?<=[.!?])\s+|\n+/).any? do |sentence|
      sentence.match?(COLLEAGUE_PROMISE) && !sentence.match?(NOT_A_PROMISE)
    end
  end

  def initialize(assistant:, response:, customer_message:, composer:)
    @assistant = assistant
    @response = response
    @customer_message = customer_message
    @composer = composer
  end

  def tool_fired? = self.class.tool_fired?(@response)

  def declared? = self.class.declared?(@response)

  def safety_net_triggered?
    return false unless @assistant.handoff_safety_net?

    Captain::Conversation::HandoffSafetyNet.new(
      assistant: @assistant,
      customer_message: @customer_message,
      answer: Captain::Assistant::ResponseParts.from_response(@response).plain_text
    ).triggered?
  end

  def empty_response? = @composer.empty_response?

  def source
    if tool_fired? then Captain::ConversationEvents::Sources::TOOL
    elsif declared? then Captain::ConversationEvents::Sources::DECLARED
    elsif safety_net_triggered? then Captain::ConversationEvents::Sources::SAFETY_NET
    elsif empty_response? then EMPTY_RESPONSE
    end
  end
end
