# frozen_string_literal: true

require "json"

# Idempotent consumer: the message id is recorded in ghk_inbox in the same transaction as the
# handler, so redeliveries are acknowledged without running the handler twice. A handler error
# rejects the message without requeue, so RabbitMQ dead-letters it to the DLQ.
class InboxConsumer
  def initialize(database_url, channel, queue, consumer_name, schema = "public", &handler)
    @database_url = database_url
    @channel = channel
    @queue = channel.queue(queue, passive: true)
    @consumer_name = consumer_name
    @handler = handler
    @s = RuntimeSchema.name_for(schema)
  end

  # Processes messages until the queue stays empty for idle_seconds; returns how many were processed.
  def drain(idle_seconds = 1.0)
    processed = 0
    idle_since = Time.now
    while Time.now - idle_since < idle_seconds
      delivery, properties, body = @queue.pop(manual_ack: true)
      if delivery.nil?
        sleep 0.05
        next
      end
      process(delivery, properties, body)
      processed += 1
      idle_since = Time.now
    end
    processed
  end

  private

  def process(delivery, properties, body)
    headers = properties.headers || {}
    span = RuntimeTelemetry.tracer.start_span("#{@queue.name} process", with_parent: RuntimeTelemetry.context_from(headers["traceparent"]), kind: :consumer,
                                              attributes: { "messaging.system" => "rabbitmq", "messaging.destination.name" => @queue.name,
                                                            "messaging.message.id" => properties.message_id.to_s })
    conn = PG.connect(@database_url)
    conn.transaction do |tx|
      first = tx.exec_params("INSERT INTO #{@s}.ghk_inbox (consumer, message_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", [@consumer_name, properties.message_id])
      if first.cmd_tuples == 1
        @handler.call(JSON.parse(body), { message_id: properties.message_id, tenant_id: headers["tenant_id"], event_type: properties.type, connection: tx })
      end
    end
    @channel.ack(delivery.delivery_tag)
  rescue StandardError => e
    span.record_exception(e)
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    @channel.reject(delivery.delivery_tag, false)
  ensure
    conn&.close
    span.finish
  end
end
