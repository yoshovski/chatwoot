module Captain::Conversation::CompactionTracing
  def perform(conversation, assistant)
    Captain::Tracing.operation('captain.memory.compaction', assistant: assistant, conversation: conversation) { super }
  end
end
