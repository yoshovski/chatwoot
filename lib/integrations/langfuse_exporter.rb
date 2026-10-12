require 'integrations/trace_sanitizer'

# Applies the live tracing/content switches to every instrumentation source, including ai-agents.
class Integrations::LangfuseExporter
  def initialize(exporter)
    @exporter = exporter
  end

  def export(spans, timeout: nil)
    enabled = ActiveRecord::Base.connection_pool.with_connection { ChatwootApp.otel_enabled? }
    return OpenTelemetry::SDK::Trace::Export::SUCCESS unless enabled

    capture = ActiveRecord::Base.connection_pool.with_connection do
      InstallationConfig.find_by(name: 'LANGFUSE_CAPTURE_CONTENT')&.value.to_s == 'true'
    end
    @exporter.export(spans.map { |span| Integrations::TraceSanitizer.span(span, capture: capture) }, timeout: timeout)
  rescue StandardError => e
    Rails.logger.warn "[Langfuse] export_failed error=#{e.class.name}"
    OpenTelemetry::SDK::Trace::Export::FAILURE
  end

  def force_flush(timeout: nil) = @exporter.force_flush(timeout: timeout)
  def shutdown(timeout: nil) = @exporter.shutdown(timeout: timeout)
end
