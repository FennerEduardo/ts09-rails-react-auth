# frozen_string_literal: true

require "json"

# Idempotent consumer: the message id is recorded in ghk_inbox in the same transaction as the
# handler, so redeliveries are acknowledged without running the handler twice. A handler error
# dead-letters the message (RabbitMQ DLX, Pub/Sub dead-letter topic): it is not redelivered.
class InboxConsumer
  def initialize(database_url, subscription, consumer_name, schema = "public", &handler)
    @database_url = database_url
    @subscription = subscription
    @consumer_name = consumer_name
    @handler = handler
    @s = RuntimeSchema.name_for(schema)
  end

  # Processes messages until the source stays empty for idle_seconds; returns how many were processed.
  def drain(idle_seconds = 1.0)
    processed = 0
    idle_since = Time.now
    while Time.now - idle_since < idle_seconds
      delivery = @subscription.poll
      if delivery.nil?
        sleep 0.05
        next
      end
      process(delivery)
      processed += 1
      idle_since = Time.now
    end
    processed
  end

  private

  def process(delivery)
    message = delivery.message
    source = @subscription.source
    span = RuntimeTelemetry.tracer.start_span("#{source} process", with_parent: RuntimeTelemetry.context_from(message.traceparent), kind: :consumer,
                                              attributes: { "messaging.system" => @subscription.system, "messaging.destination.name" => source,
                                                            "messaging.message.id" => message.message_id.to_s })
    conn = PG.connect(@database_url)
    conn.transaction do |tx|
      first = tx.exec_params("INSERT INTO #{@s}.ghk_inbox (consumer, message_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", [@consumer_name, message.message_id])
      if first.cmd_tuples == 1
        @handler.call(JSON.parse(message.body), { message_id: message.message_id, tenant_id: message.tenant_id, event_type: message.event_type, connection: tx })
      end
    end
    delivery.ack
  rescue StandardError => e
    span.record_exception(e)
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    delivery.dead_letter
  ensure
    conn&.close
    span.finish
  end
end
