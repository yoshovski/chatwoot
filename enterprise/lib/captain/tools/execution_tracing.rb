# The agent SDK creates tool spans explicitly; make that tool the active parent during its work.
module Captain::Tools::ExecutionTracing
  def execute(tool_context, **params)
    return super unless ChatwootApp.otel_enabled? && tool_context.respond_to?(:context)

    tracing = tool_context.context[:__otel_tracing]
    tool_span = tracing&.dig(:current_tool_span)
    return super unless tool_span

    OpenTelemetry::Context.with_current(OpenTelemetry::Trace.context_with_span(tool_span)) { super }
  end
end
