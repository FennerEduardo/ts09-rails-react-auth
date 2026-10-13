# frozen_string_literal: true

# Topic exchange -> consumer queue, which dead-letters rejected messages to a fanout DLX -> DLQ.
RuntimeTopology = Struct.new(:exchange, :queue, :dlx, :dlq) do
  def self.default
    new("ruby-rails-react-auth.events", "ruby-rails-react-auth.consumer", "ruby-rails-react-auth.dlx", "ruby-rails-react-auth.dlq")
  end

  def self.for_prefix(prefix)
    new("#{prefix}.events", "#{prefix}.consumer", "#{prefix}.dlx", "#{prefix}.dlq")
  end

  def declare(channel)
    events = channel.topic(exchange, durable: true)
    dead = channel.fanout(dlx, durable: true)
    channel.queue(dlq, durable: true).bind(dead)
    channel.queue(queue, durable: true, arguments: { "x-dead-letter-exchange" => dlx }).bind(events, routing_key: "#")
  end
end
