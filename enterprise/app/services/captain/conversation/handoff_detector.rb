# Reads from one V2 run whether the customer is being handed to a colleague. The chat job acts on it (and adds the
# conversation state checks); the playground only reports it.
class Captain::Conversation::HandoffDetector
  EMPTY_RESPONSE = 'empty_response'.freeze

  def self.tool_fired?(response) = response['handoff_tool_called']

  def self.declared?(response) = response['handoff_requested'] == true

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
