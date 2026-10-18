# frozen_string_literal: true

# The event broker behind the outbox relay and the inbox consumer, chosen at run time so one image runs on any
# cloud: GHK_BROKER=rabbitmq (AMQP_URL) or pubsub (PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT; PUBSUB_EMULATOR_HOST).
# Without GHK_BROKER the configured variables decide, then stack.messaging.
# Azure Service Bus has no official Ruby SDK: on Azure use self-managed RabbitMQ or CloudAMQP (AMQP_URL).
#
# Brokers answer: system, dynamic_topology?, declare(topology), publisher(destination), subscribe(source, topology),
# close. Publishers: system, destination, publish(message) (returns once the broker accepted it), close.
# Subscriptions: system, source, poll (a BrokerDelivery or nil), close.
module EventBroker
  # Broker of the generated configuration (stack.messaging).
  DEFAULT_KIND = "rabbitmq"

  def self.env(key)
    value = ENV.fetch(key, "").strip
    value.empty? ? nil : value
  end

  def self.kind
    return env("GHK_BROKER").downcase if env("GHK_BROKER")
    return "rabbitmq" if env("AMQP_URL")
    return "pubsub" if env("PUBSUB_PROJECT_ID") || env("PUBSUB_EMULATOR_HOST")

    DEFAULT_KIND
  end

  # Whether the variables of the selected broker are set.
  def self.configured?
    kind == "pubsub" ? !(env("PUBSUB_PROJECT_ID") || env("GOOGLE_CLOUD_PROJECT")).nil? : !env("AMQP_URL").nil?
  end

  def self.connect
    case kind
    when "rabbitmq"
      RabbitMqBroker.new(env("AMQP_URL") || raise("AMQP_URL is not set (amqp://user:password@host:5672)"))
    when "pubsub" then PubSubBroker.from_env
    when "servicebus" then raise "Azure Service Bus has no official Ruby SDK: use RabbitMQ (self-managed or CloudAMQP) on Azure"
    else raise "Unsupported GHK_BROKER: #{kind} (rabbitmq, pubsub)"
    end
  end
end
