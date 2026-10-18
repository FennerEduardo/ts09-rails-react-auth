# frozen_string_literal: true

require "bunny"

# RabbitMQ 0-9-1: topic exchange, publisher confirms, dead-lettering through the queue's DLX.
class RabbitMqBroker
  def initialize(url)
    @connection = Bunny.new(url, logger: Logger.new(nil)).tap(&:start)
  end

  def system = "rabbitmq"
  def dynamic_topology? = true

  def declare(topology)
    channel = @connection.create_channel
    events = channel.topic(topology.exchange, durable: true)
    dead = channel.fanout(topology.dlx, durable: true)
    channel.queue(topology.dlq, durable: true).bind(dead)
    channel.queue(topology.queue, durable: true, arguments: { "x-dead-letter-exchange" => topology.dlx }).bind(events, routing_key: "#")
  ensure
    channel&.close
  end

  def publisher(exchange)
    Publisher.new(@connection.create_channel, exchange)
  end

  def subscribe(queue, _topology)
    Subscription.new(@connection.create_channel, queue)
  end

  def close
    @connection.close if @connection.open?
  end

  # One channel per publisher (use one per thread).
  class Publisher
    attr_reader :destination

    def initialize(channel, exchange)
      @channel = channel
      @channel.confirm_select
      @exchange = channel.topic(exchange, durable: true)
      @destination = exchange
    end

    def system = "rabbitmq"

    def publish(message)
      headers = {}
      headers["tenant_id"] = message.tenant_id if message.tenant_id
      headers["traceparent"] = message.traceparent if message.traceparent
      @exchange.publish(message.body, routing_key: message.event_type.to_s, message_id: message.message_id, persistent: true,
                                      content_type: "application/json", type: message.event_type, headers: headers)
      raise "broker did not confirm #{message.message_id}" unless @channel.wait_for_confirms
    end

    def close
      @channel.close if @channel.open?
    end
  end

  class Subscription
    attr_reader :source

    def initialize(channel, queue)
      @channel = channel
      @queue = channel.queue(queue, passive: true)
      @source = queue
    end

    def system = "rabbitmq"

    def poll
      delivery, properties, body = @queue.pop(manual_ack: true)
      return nil if delivery.nil?

      headers = properties.headers || {}
      message = BrokerMessage.new(message_id: properties.message_id.to_s, event_type: properties.type, tenant_id: headers["tenant_id"]&.to_s,
                                  traceparent: headers["traceparent"]&.to_s, body: body)
      tag = delivery.delivery_tag
      # Rejected without requeue: RabbitMQ dead-letters it through the queue's DLX.
      BrokerDelivery.new(message, -> { @channel.ack(tag) }, -> { @channel.reject(tag, false) })
    end

    def close
      @channel.close if @channel.open?
    end
  end
end
