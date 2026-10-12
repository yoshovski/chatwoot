class Captain::Conversation::MemoryContextService
  def initialize(conversation:, assistant:)
    @conversation = conversation
    @assistant = assistant
    @compactor = Captain::Conversation::MemoryCompactor.new(conversation: conversation, assistant: assistant)
  end

  def prepare(history:)
    snapshot = Captain::Conversation::MemorySnapshot.new(history)
    memory = @compactor.memory_record
    return result(snapshot.history, nil, snapshot, usable: false) unless @compactor.validate_memory!(memory, snapshot)

    uncovered = snapshot.uncovered(memory)
    tokens = Captain::Conversation::ContextBudget.tokens(uncovered)
    return catch_up(snapshot) if tokens > Captain::Conversation::ContextBudget.hard_tokens

    schedule if tokens > Captain::Conversation::ContextBudget.trigger_tokens
    result(uncovered, memory, snapshot, usable: true)
  rescue StandardError => e
    Rails.logger.warn "[Captain][MemoryContext] fallback=full_history error=#{e.class.name}"
    result(snapshot&.history || history, nil, snapshot, usable: false)
  end

  private

  def catch_up(snapshot)
    @compactor.compact!(force: true, timeout: Float(ENV.fetch('CAPTAIN_MEMORY_CATCH_UP_TIMEOUT', '2')))
    memory = @compactor.memory_record.reload
    return result(snapshot.history, nil, snapshot, usable: false) unless snapshot.valid?(memory)

    uncovered = snapshot.uncovered(memory)
    tokens = Captain::Conversation::ContextBudget.tokens(uncovered)
    usable = tokens <= Captain::Conversation::ContextBudget.hard_tokens
    schedule if tokens > Captain::Conversation::ContextBudget.trigger_tokens
    result(uncovered, memory, snapshot, usable: usable)
  end

  def schedule
    Captain::Conversation::MemoryCompactionJob.perform_later(@conversation, @assistant)
  end

  def result(history, memory, snapshot, usable:)
    {
      history: history,
      usable: usable,
      memory: { summary: memory&.summary.to_s, facts: memory&.facts || [], covered_message_id: memory&.covered_message_id || 0,
                revision: memory&.revision || 0, active_agent_name: snapshot&.active_agent_name }
    }
  end
end
