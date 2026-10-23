# OpenTelemetry export of the running service: with OTEL_EXPORTER_OTLP_ENDPOINT set, spans go over OTLP/HTTP to
# that collector (service.name from OTEL_SERVICE_NAME); without it nothing is exported and nothing connects.
if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].to_s != "" && !Rails.env.test?
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"

  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "ruby-rails-react-auth")
  end
  at_exit { OpenTelemetry.tracer_provider.shutdown }
end
