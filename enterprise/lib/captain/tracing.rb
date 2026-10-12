module Captain::Tracing
  def self.operation(name, assistant:, conversation: nil, type: 'chain', input: nil)
    return yield(nil) unless ChatwootApp.otel_enabled?

    OpentelemetryConfig.tracer.in_span(name, attributes: attributes(assistant, conversation, type)) do |span|
      span.set_attribute('langfuse.observation.input', input.to_json) unless input.nil?
      yield(span)
    rescue StandardError => e
      span.set_attribute('error.type', e.class.name)
      raise
    end
  end

  def self.attributes(assistant, conversation, type)
    values = {
      'langfuse.observation.type' => type,
      'langfuse.user.id' => assistant.account_id.to_s,
      'langfuse.trace.tags' => ['captain'],
      'langfuse.trace.metadata.account_id' => assistant.account_id.to_s,
      'langfuse.trace.metadata.assistant_id' => assistant.id.to_s,
      'langfuse.environment' => Rails.env.to_s
    }
    values['langfuse.session.id'] = "#{assistant.account_id}_#{conversation.display_id}" if conversation
    values
  end

  def self.result(span, result)
    return unless span

    span.set_attribute('langfuse.observation.output', result.to_json)
    return unless result.is_a?(Hash) && (result['error'] || result[:error])

    span.status = OpenTelemetry::Trace::Status.error('Operation failed')
  end

  def self.generation(stage, assistant:, chat:, input:)
    messages = chat.messages.map { |message| { role: message.role, content: message.content } } + [{ role: :user, content: input }]
    operation("captain.#{stage}", assistant: assistant, type: 'generation', input: messages) do |span|
      span&.set_attribute('gen_ai.request.model', chat.model.id.to_s)
      span&.set_attribute('gen_ai.provider.name', 'litellm')
      response = yield
      if span
        span.set_attribute('langfuse.observation.output', response.content.to_json)
        span.set_attribute('gen_ai.usage.input_tokens', response.input_tokens) if response.input_tokens
        span.set_attribute('gen_ai.usage.output_tokens', response.output_tokens) if response.output_tokens
      end
      response
    end
  end
end
