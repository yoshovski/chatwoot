class Captain::Conversation::ContextBudget
  # Local conservative estimate; UTF-8 bytes avoid undercounting non-Latin text as characters.
  # Actual provider usage should be used to tune these application budgets.
  def self.tokens(value)
    text = value.is_a?(String) ? value : value.to_json
    (text.bytesize / 3.0).ceil
  end

  def self.partition(messages, keep_tokens:)
    index = messages.size
    total = 0
    messages.reverse_each do |message|
      size = tokens(message[:content])
      break if total + size > keep_tokens && index < messages.size

      total += size
      index -= 1
    end
    # Retain a whole exchange and every entry belonging to the boundary message.
    index -= 1 while index.positive? && (messages[index][:role].to_s != 'user' || messages[index][:message_id] == messages[index - 1][:message_id])
    [messages.take(index), messages.drop(index)]
  end

  def self.recent_tokens = Integer(ENV.fetch('CAPTAIN_MEMORY_RECENT_TOKENS', '3000'))
  def self.trigger_tokens = Integer(ENV.fetch('CAPTAIN_MEMORY_TRIGGER_TOKENS', '6000'))
  def self.hard_tokens = Integer(ENV.fetch('CAPTAIN_MEMORY_HARD_TOKENS', '8000'))
end
