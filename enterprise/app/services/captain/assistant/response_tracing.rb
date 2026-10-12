# One active response scope joins direct routing and existing agent instrumentation.
module Captain::Assistant::ResponseTracing
  def generate_response(message_history: [])
    Captain::Tracing.operation('captain.response', assistant: @assistant, conversation: @conversation) do |span|
      result = super
      Captain::Tracing.result(span, result)
      span&.set_attribute('langfuse.observation.metadata.discarded', response_discarded?.to_s)
      result
    end
  end
end
