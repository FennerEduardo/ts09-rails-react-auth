# frozen_string_literal: true

namespace :outbox do
  desc "Publish the transactional outbox to the event broker until interrupted (DATABASE_URL; AMQP_URL or PUBSUB_*)"
  task relay: :environment do
    broker = EventBroker.connect
    broker.declare(RuntimeTopology.default)
    publisher = broker.publisher(RuntimeTopology.default.exchange)
    relay = OutboxRelay.new(ENV.fetch("DATABASE_URL"), publisher)
    worker_id = "autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-#{SecureRandom.hex(6)}"
    loop do
      relay.publish_batch(worker_id)
      sleep 1
    end
  ensure
    publisher&.close
    broker&.close
  end
end
