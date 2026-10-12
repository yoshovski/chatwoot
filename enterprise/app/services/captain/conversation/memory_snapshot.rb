class Captain::Conversation::MemorySnapshot
  attr_reader :history, :boundary_message_id

  def initialize(history)
    boundary = history.rindex { |entry| entry[:content] == Captain::Conversation::MessageHistoryBuilderService::RESOLUTION_MARKER }
    @boundary_message_id = boundary ? history[boundary].fetch(:message_id) : 0
    @history = boundary ? history.drop(boundary + 1) : history
  end

  def digest(cursor)
    Digest::SHA256.hexdigest(history.select { |entry| entry[:message_id] <= cursor }.map { |entry| entry.slice(:message_id, :source_digest) }.to_json)
  end

  def valid?(memory)
    return false unless memory.boundary_message_id == boundary_message_id
    return true if memory.covered_message_id.zero?

    memory.prompt_version == Captain::Conversation::MemorySummarizer::PROMPT_VERSION &&
      history.any? { |entry| entry[:message_id] == memory.covered_message_id } && digest(memory.covered_message_id) == memory.source_digest
  end

  def uncovered(memory)
    history.select { |entry| entry[:message_id] > memory.covered_message_id }
  end

  def older_than_recent(memory)
    Captain::Conversation::ContextBudget.partition(uncovered(memory), keep_tokens: Captain::Conversation::ContextBudget.recent_tokens).first
  end

  def active_agent_name
    history.reverse.find { |entry| entry[:role].to_s == 'assistant' }&.dig(:agent_name)
  end
end
