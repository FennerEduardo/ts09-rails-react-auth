# frozen_string_literal: true

# Publishes pending outbox rows. Rows are claimed with FOR UPDATE SKIP LOCKED and a lease, so
# concurrent relays never publish the same row; publisher confirms guarantee delivery to the broker
# before a row is marked published. Use one relay (and channel) per thread.
class OutboxRelay
  def initialize(database_url, channel, exchange = RuntimeTopology.default.exchange, schema = "public", lease_seconds: 30, max_attempts: 5)
    @database_url = database_url
    @channel = channel
    @channel.confirm_select
    @exchange = channel.topic(exchange, durable: true)
    @s = RuntimeSchema.name_for(schema)
    @lease_seconds = lease_seconds
    @max_attempts = max_attempts
  end

  def publish_batch(worker_id, limit = 50)
    conn = PG.connect(@database_url)
    rows = conn.exec_params(
      "UPDATE #{@s}.ghk_outbox SET claimed_by = $1, claimed_until = now() + make_interval(secs => $2), attempts = attempts + 1 " \
      "WHERE id IN (SELECT id FROM #{@s}.ghk_outbox WHERE published_at IS NULL AND failed_at IS NULL AND (claimed_until IS NULL OR claimed_until < now()) " \
      "ORDER BY created_at LIMIT $3 FOR UPDATE SKIP LOCKED) RETURNING id, tenant_id, event_type, payload, traceparent",
      [worker_id, @lease_seconds, limit]
    ).to_a
    rows.count { |row| publish(conn, row, worker_id) }
  ensure
    conn&.close
  end

  private

  def publish(conn, row, worker_id)
    parent = RuntimeTelemetry.context_from(row["traceparent"])
    span = RuntimeTelemetry.tracer.start_span("#{@exchange.name} publish", with_parent: parent, kind: :producer,
                                              attributes: { "messaging.system" => "rabbitmq", "messaging.destination.name" => @exchange.name,
                                                            "messaging.message.id" => row["id"], "tenant.id" => row["tenant_id"] })
    headers = { "tenant_id" => row["tenant_id"] }
    traceparent = RuntimeTelemetry.traceparent_of(span, parent)
    headers["traceparent"] = traceparent if traceparent
    @exchange.publish(row["payload"], routing_key: row["event_type"], message_id: row["id"], persistent: true,
                                      content_type: "application/json", type: row["event_type"], headers: headers)
    raise "broker did not confirm #{row['id']}" unless @channel.wait_for_confirms

    conn.exec_params("UPDATE #{@s}.ghk_outbox SET published_at = now(), claimed_until = NULL WHERE id = $1 AND claimed_by = $2", [row["id"], worker_id])
    true
  rescue StandardError => e
    span.record_exception(e)
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    conn.exec_params("UPDATE #{@s}.ghk_outbox SET claimed_until = NULL, last_error = $2, failed_at = CASE WHEN attempts >= $3 THEN now() ELSE NULL END WHERE id = $1",
                     [row["id"], e.message, @max_attempts])
    false
  ensure
    span.finish
  end
end
