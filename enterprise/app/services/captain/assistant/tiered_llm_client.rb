# Uses the same Captain credentials and LiteLLM endpoint, with request-local settings.
class Captain::Assistant::TieredLlmClient
  def self.measure(stage, assistant)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    return yield unless ChatwootApp.otel_enabled?

    OpentelemetryConfig.tracer.in_span("llm.captain.#{stage}") do |span|
      span.set_attribute('captain.assistant_id', assistant.id.to_s)
      yield
    end
  ensure
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    Rails.logger.info "[Captain][TieredLLM] stage=#{stage} duration_ms=#{elapsed} assistant_id=#{assistant.id}"
  end

  def self.generate(stage, assistant, chat, input)
    measure(stage, assistant) do
      Captain::Tracing.generation(stage, assistant: assistant, chat: chat, input: input) { chat.ask(input) }
    end
  end

  def self.chat(model:, timeout:, account_id:)
    Llm::Config.initialize!
    context = RubyLLM.context do |config|
      config.request_timeout = timeout
      config.max_retries = 0
    end
    context.chat(model: model, provider: :openai, assume_model_exists: true).with_temperature(0)
           .with_headers(**Llm::TenantTracking.headers(account_id: account_id, feature: model))
  end
end
