class Captain::Conversation::MemoryCompactionJob < MutexApplicationJob
  queue_as :low

  def perform(conversation, assistant)
    return unless Captain::Assistant::TieredRoutingHelper.mode_for(assistant.account_id).in?(%w[shadow on])

    more = false
    with_lock("captain_memory:#{conversation.account_id}:#{conversation.id}:#{assistant.id}", 2.minutes) do
      compactor = Captain::Conversation::MemoryCompactor.new(conversation: conversation, assistant: assistant)
      next unless compactor.compact!

      snapshot = compactor.current_snapshot
      remaining = snapshot.uncovered(compactor.memory_record.reload)
      more = Captain::Conversation::ContextBudget.tokens(remaining) > Captain::Conversation::ContextBudget.trigger_tokens
    end
    self.class.perform_later(conversation, assistant) if more
  rescue StandardError => e
    Rails.logger.warn "[Captain][MemoryCompaction] error=#{e.class.name} conversation_id=#{conversation.id}"
  end
end
