# Removes recognized credentials and exception bodies from exported spans. Content capture is explicitly opt-in.
class Integrations::TraceSanitizer
  SECRET_KEY = /authorization|cookie|password|secret|api.?key|access.?token|refresh.?token|encryption.?key|tool.?key/i
  SAFE_METADATA = %w[error.type langfuse.observation.metadata.result_count result_count].freeze
  CONTENT_KEY = /(?:input|output|content|arguments|result|prompt|completion|reason|error|exception)/i

  def self.span(source, capture:)
    source.dup.tap do |copy|
      copy.start_timestamp = inference_start(source)
      copy.attributes = attributes(source.attributes, capture: capture).except('captain.inference_start_ns')
      copy.events = Array(source.events).reject { |event| event.name == 'exception' }.map do |event|
        event.dup.tap { |item| item.attributes = attributes(event.attributes, capture: capture) }
      end
      copy.status = OpenTelemetry::Trace::Status.error('Operation failed') if source.status.code == OpenTelemetry::Trace::Status::ERROR
    end
  end

  def self.inference_start(source)
    started_at = source.attributes&.fetch('captain.inference_start_ns', nil)
    started_at.is_a?(Integer) && started_at <= source.start_timestamp ? started_at : source.start_timestamp
  end

  def self.attributes(values, capture:)
    values.to_h.each_with_object({}) do |(key, value), output|
      next if key.match?(SECRET_KEY)
      next if !capture && content_attribute?(key)

      output[key] = sanitize(value)
    end
  end

  def self.content_attribute?(key)
    key.match?(CONTENT_KEY) && SAFE_METADATA.exclude?(key) && !key.start_with?('gen_ai.usage.', 'gen_ai.request.', 'gen_ai.response.model')
  end

  def self.sanitize(value)
    case value
    when Hash then value.except(*value.keys.select { |key| key.to_s.match?(SECRET_KEY) }).transform_values { |item| sanitize(item) }
    when Array then value.map { |item| sanitize(item) }
    when String then sanitize_text(value)
    else value
    end
  end

  def self.sanitize_text(value)
    parsed = JSON.parse(value)
    sanitize(parsed).to_json
  rescue JSON::ParserError
    value.gsub(/Bearer\s+[^\s"<>]+/i, 'Bearer [REDACTED]')
         .gsub(/((?:api[_-]?key|access[_-]?token|refresh[_-]?token|secret|password|authorization)\s*[=:]\s*)[^\s&,"<>]+/i, '\1[REDACTED]')
         .gsub(/\b(?:sk|pk)-(?:lf-)?[a-zA-Z0-9_-]{8,}/, '[REDACTED]')
         .truncate(32_000)
  end
end
