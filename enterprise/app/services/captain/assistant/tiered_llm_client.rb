# Uses the same Captain credentials and LiteLLM endpoint, with request-local settings.
class Captain::Assistant::TieredLlmClient
  USAGE_THREAD_KEY = :captain_tiered_llm_usage

  def self.track_usage
    previous = Thread.current[USAGE_THREAD_KEY]
    tracker = { calls: 0, retries: 0, input_tokens: 0, output_tokens: 0, cached_tokens: 0, elapsed_ms: 0, stages: {} }
    Thread.current[USAGE_THREAD_KEY] = tracker
    [yield(tracker), tracker]
  ensure
    Thread.current[USAGE_THREAD_KEY] = previous
  end

  def self.cost_report(tracker, input_rate: nil, output_rate: nil)
    input_tokens = tracker[:input_tokens].to_i
    output_tokens = tracker[:output_tokens].to_i
    cost_usd = (input_tokens * input_rate.to_f) + (output_tokens * output_rate.to_f) if input_rate && output_rate
    {
      'calls' => tracker[:calls].to_i,
      'retries' => tracker[:retries].to_i,
      'input_tokens' => input_tokens,
      'output_tokens' => output_tokens,
      'cached_tokens' => tracker[:cached_tokens].to_i,
      'elapsed_ms' => tracker[:elapsed_ms].to_i,
      'cost_usd' => cost_usd&.round(6),
      'currency_status' => cost_usd ? 'measured' : 'unknown'
    }
  end

  def self.measure(stage, assistant)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    return yield unless ChatwootApp.otel_enabled?

    OpentelemetryConfig.tracer.in_span("llm.captain.#{stage}") do |span|
      span.set_attribute('captain.assistant_id', assistant.id.to_s)
      yield
    end
  ensure
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    record_stage_elapsed(stage, elapsed)
    Rails.logger.info "[Captain][TieredLLM] stage=#{stage} duration_ms=#{elapsed} assistant_id=#{assistant.id}"
  end

  def self.generate(stage, assistant, chat, input)
    response = measure(stage, assistant) do
      Captain::Tracing.generation(stage, assistant: assistant, chat: chat, input: input) { chat.ask(input) }
    end
    record_response_usage(stage, response)
    response
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

  def self.record_stage_elapsed(stage, elapsed)
    tracker = Thread.current[USAGE_THREAD_KEY]
    return unless tracker

    tracker[:elapsed_ms] += elapsed
    stage_entry = (tracker[:stages][stage.to_s] ||= { calls: 0, input_tokens: 0, output_tokens: 0, cached_tokens: 0, elapsed_ms: 0 })
    stage_entry[:elapsed_ms] += elapsed
  end
  private_class_method :record_stage_elapsed

  def self.record_response_usage(stage, response)
    tracker = Thread.current[USAGE_THREAD_KEY]
    return unless tracker

    tokens = extract_response_tokens(response)
    accumulate_tokens(tracker, tokens)
    stage_entry = (tracker[:stages][stage.to_s] ||= { calls: 0, input_tokens: 0, output_tokens: 0, cached_tokens: 0, elapsed_ms: 0 })
    accumulate_tokens(stage_entry, tokens)
  end
  private_class_method :record_response_usage

  def self.extract_response_tokens(response)
    {
      input: response.respond_to?(:input_tokens) ? response.input_tokens.to_i : 0,
      output: response.respond_to?(:output_tokens) ? response.output_tokens.to_i : 0,
      cached: response.respond_to?(:cached_tokens) ? response.cached_tokens.to_i : 0
    }
  end
  private_class_method :extract_response_tokens

  def self.accumulate_tokens(target, tokens)
    target[:calls] += 1
    target[:input_tokens] += tokens[:input]
    target[:output_tokens] += tokens[:output]
    target[:cached_tokens] += tokens[:cached]
  end
  private_class_method :accumulate_tokens
end
