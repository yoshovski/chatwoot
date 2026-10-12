class Captain::Conversation::MemoryCompactor
  INPUT_TOKENS = 12_000

  def initialize(conversation:, assistant:)
    raise ArgumentError, 'Conversation and assistant account mismatch' unless conversation.account_id == assistant.account_id

    @conversation = conversation
    @assistant = assistant
  end

  def compact!(force: false, timeout: nil)
    snapshot = current_snapshot
    memory = memory_record
    return false unless validate_memory!(memory, snapshot)

    uncovered = snapshot.uncovered(memory)
    return false unless force || Captain::Conversation::ContextBudget.tokens(uncovered) > Captain::Conversation::ContextBudget.trigger_tokens

    messages = batch(snapshot.older_than_recent(memory))
    return false unless compactable?(messages, uncovered)

    revision = memory.revision
    cursor = messages.last.fetch(:message_id)
    source_ids = snapshot.history.select { |entry| entry[:message_id] <= cursor }.pluck(:message_id).uniq
    output = summarizer.summarize(previous: memory.slice(:summary, :facts), messages: messages, source_ids: source_ids, timeout: timeout)
    store_if_current(memory, snapshot, cursor, revision, output)
  end

  def current_snapshot
    history = Captain::Conversation::MessageHistoryBuilderService.new(conversation: @conversation).perform(include_message_ids: true)
    Captain::Conversation::MemorySnapshot.new(history)
  end

  def memory_record
    Captain::ConversationMemory.find_or_create_by!(account_id: @assistant.account_id, conversation_id: @conversation.id, assistant_id: @assistant.id)
  end

  def validate_memory!(memory, snapshot)
    memory.with_lock do
      return false if snapshot.history.any? && memory.covered_message_id > snapshot.history.pluck(:message_id).max

      memory.invalidate!(boundary_message_id: snapshot.boundary_message_id) unless snapshot.valid?(memory)
      true
    end
  end

  private

  def summarizer
    @summarizer ||= Captain::Conversation::MemorySummarizer.new(assistant: @assistant)
  end

  def batch(messages)
    tokens = Captain::Conversation::ContextBudget.tokens(messages)
    return messages if tokens <= INPUT_TOKENS

    Captain::Conversation::ContextBudget.partition(messages, keep_tokens: tokens - INPUT_TOKENS).first
  end

  def compactable?(messages, uncovered)
    return false if messages.empty? || messages.any? { |entry| !entry[:content].is_a?(String) }

    # Imported/backdated messages can have non-monotonic IDs. Never advance past an uncovered earlier ID.
    cursor = messages.last.fetch(:message_id)
    messages.pluck(:message_id).max == cursor && uncovered.drop(messages.size).all? { |entry| entry[:message_id] > cursor }
  end

  def store_if_current(memory, snapshot, cursor, revision, output)
    memory.with_lock do
      return false unless memory.revision == revision

      fresh = current_snapshot
      return false unless fresh.boundary_message_id == snapshot.boundary_message_id && fresh.digest(cursor) == snapshot.digest(cursor)

      memory.update!(summary: output.fetch('summary'), facts: output.fetch('facts'), covered_message_id: cursor,
                     boundary_message_id: snapshot.boundary_message_id, source_digest: snapshot.digest(cursor), revision: revision + 1,
                     model: summarizer.model, prompt_version: Captain::Conversation::MemorySummarizer::PROMPT_VERSION)
    end
    true
  end
end
