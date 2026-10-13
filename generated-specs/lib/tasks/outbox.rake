# frozen_string_literal: true

namespace :outbox do
  desc "Publish the transactional outbox to RabbitMQ until interrupted (DATABASE_URL, AMQP_URL)"
  task relay: :environment do
    connection = Bunny.new(ENV.fetch("AMQP_URL"), logger: Logger.new(nil)).tap(&:start)
    channel = connection.create_channel
    RuntimeTopology.default.declare(channel)
    relay = OutboxRelay.new(ENV.fetch("DATABASE_URL"), channel, RuntimeTopology.default.exchange)
    worker_id = "autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-#{SecureRandom.hex(6)}"
    loop do
      relay.publish_batch(worker_id)
      sleep 1
    end
  ensure
    connection&.close
  end
end
