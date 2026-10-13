# frozen_string_literal: true

require "json"
require "securerandom"

# Executes a command in one transaction: idempotency claim, aggregate load (FOR UPDATE), domain
# logic, aggregate save and outbox insert. A domain error rolls back everything.
class CommandService
  # Aggregate type used when a request does not name one.
  DEFAULT_AGGREGATE = "AutenticacionJwtYCreacionDePedidosEnRails7Api"
  # Every aggregate of the service: aggregate class, command class and command names.
  AGGREGATES = {
    "AutenticacionJwtYCreacionDePedidosEnRails7Api" => { aggregate: AutenticacionJwtYCreacionDePedidosEnRails7ApiAggregate, command: AutenticacionJwtYCreacionDePedidosEnRails7ApiCommand, commands: %w[process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api] }
  }.freeze

  Result = Struct.new(:status, :aggregate_id, :event_type, :version, keyword_init: true)

  def initialize(database_url, schema = "public")
    @database_url = database_url
    @s = RuntimeSchema.name_for(schema)
  end

  def handle(tenant_id:, aggregate_id:, command:, payload: {}, idempotency_key: nil, traceparent: nil, aggregate_type: nil)
    raise DomainValidationError, "tenant_id is required" if tenant_id.to_s.empty?

    aggregate_type ||= DEFAULT_AGGREGATE
    raise DomainValidationError, "Unknown aggregate type #{aggregate_type}" unless AGGREGATES.key?(aggregate_type)

    parent = RuntimeTelemetry.context_from(traceparent)
    span = RuntimeTelemetry.tracer.start_span("#{aggregate_type}.#{command}", with_parent: parent, kind: :internal,
                                              attributes: { "tenant.id" => tenant_id, "aggregate.id" => aggregate_id })
    conn = PG.connect(@database_url)
    begin
      conn.transaction do |tx|
        execute(tx, aggregate_type, tenant_id, aggregate_id, command, payload, idempotency_key, RuntimeTelemetry.traceparent_of(span, parent))
      end
    rescue StandardError => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error(e.message)
      raise
    ensure
      conn.close
      span.finish
    end
  end

  # The aggregate as the tenant sees it (nil for other tenants' aggregates).
  def load(tenant_id, aggregate_id, aggregate_type = DEFAULT_AGGREGATE)
    conn = PG.connect(@database_url)
    row = conn.exec_params("SELECT state, version FROM #{@s}.ghk_aggregates WHERE tenant_id = $1 AND aggregate_type = $2 AND id = $3",
                           [tenant_id, aggregate_type, aggregate_id]).first
    row && { state: row["state"], version: row["version"].to_i }
  ensure
    conn&.close
  end

  private

  def execute(tx, aggregate_type, tenant_id, aggregate_id, command, payload, key, traceparent)
    kind = AGGREGATES.fetch(aggregate_type)
    if key
      claim = tx.exec_params("INSERT INTO #{@s}.ghk_idempotency (tenant_id, key, status) VALUES ($1, $2, 'PROCESSING') ON CONFLICT DO NOTHING", [tenant_id, key])
      if claim.cmd_tuples.zero?
        row = tx.exec_params("SELECT status, response FROM #{@s}.ghk_idempotency WHERE tenant_id = $1 AND key = $2", [tenant_id, key]).first
        return Result.new(**JSON.parse(row["response"], symbolize_names: true).merge(status: "replayed")) if row && row["status"] == "COMPLETED"

        return Result.new(status: "in-progress", aggregate_id: aggregate_id)
      end
    end
    row = tx.exec_params("SELECT state, version FROM #{@s}.ghk_aggregates WHERE tenant_id = $1 AND aggregate_type = $2 AND id = $3 FOR UPDATE",
                         [tenant_id, aggregate_type, aggregate_id]).first
    aggregate = row ? kind[:aggregate].restore(aggregate_id, row["state"], row["version"].to_i) : kind[:aggregate].new(aggregate_id)
    raise DomainValidationError, "Unknown command #{command}" unless kind[:commands].include?(command)

    event = aggregate.public_send(command, kind[:command].new(id: aggregate_id, payload: payload || {}))
    tx.exec_params("INSERT INTO #{@s}.ghk_aggregates (tenant_id, aggregate_type, id, state, version) VALUES ($1, $2, $3, $4, $5) " \
                   "ON CONFLICT (tenant_id, aggregate_type, id) DO UPDATE SET state = EXCLUDED.state, version = EXCLUDED.version, updated_at = now()",
                   [tenant_id, aggregate_type, aggregate_id, aggregate.state, aggregate.version])
    tx.exec_params("INSERT INTO #{@s}.ghk_outbox (id, tenant_id, aggregate_id, event_type, payload, traceparent) VALUES ($1, $2, $3, $4, $5, $6)",
                   [SecureRandom.uuid, tenant_id, aggregate_id, event.type, JSON.generate(event.to_h), traceparent])
    result = Result.new(status: "created", aggregate_id: aggregate_id, event_type: event.type, version: event.version)
    if key
      tx.exec_params("UPDATE #{@s}.ghk_idempotency SET status = 'COMPLETED', response = $3 WHERE tenant_id = $1 AND key = $2",
                     [tenant_id, key, JSON.generate(result.to_h)])
    end
    result
  end
end
