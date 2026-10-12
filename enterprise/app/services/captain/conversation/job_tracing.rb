module Captain::Conversation::JobTracing
  def perform(conversation, assistant, responding_to_message_id = nil)
    Captain::Tracing.operation('captain.delivery', assistant: assistant, conversation: conversation) do |span|
      span&.set_attribute('langfuse.observation.metadata.message_id', responding_to_message_id.to_s) if responding_to_message_id
      span&.set_attribute('langfuse.observation.metadata.queue_ms', ((Time.current - enqueued_at) * 1000).round) if enqueued_at
      super
    end
  end
end
