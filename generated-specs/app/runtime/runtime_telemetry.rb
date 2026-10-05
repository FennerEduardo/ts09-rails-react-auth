# frozen_string_literal: true

require "opentelemetry"

# W3C trace-context helpers; spans go to the global tracer provider (configure exporters with OTEL_*).
module RuntimeTelemetry
  PROPAGATOR = OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator

  def self.tracer
    OpenTelemetry.tracer_provider.tracer("autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api")
  end

  # Context whose parent is the span described by an incoming traceparent header.
  def self.context_from(traceparent)
    return OpenTelemetry::Context.current if traceparent.nil? || traceparent.empty?

    PROPAGATOR.extract({ "traceparent" => traceparent }, context: OpenTelemetry::Context.empty)
  end

  # traceparent header value for a span (nil when the span is invalid).
  def self.traceparent_of(span, parent)
    carrier = {}
    PROPAGATOR.inject(carrier, context: OpenTelemetry::Trace.context_with_span(span, parent_context: parent))
    carrier["traceparent"]
  end
end
