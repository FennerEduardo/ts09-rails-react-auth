# frozen_string_literal: true

# Runtime integration tests (docs/RUNTIME-KERNEL.md, IT1-IT7) against PostgreSQL and the selected broker
# (GHK_BROKER: rabbitmq with AMQP_URL, pubsub with PUBSUB_PROJECT_ID [+ PUBSUB_EMULATOR_HOST]).
# Requires DATABASE_URL. Run with: bundle exec rspec --tag integration
ENV["OTEL_TRACES_EXPORTER"] ||= "none"
require "rails_helper"
require "opentelemetry/sdk"
require "securerandom"

EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
OpenTelemetry::SDK.configure { |c| c.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER)) }

RSpec.describe "AutenticacionJwtYCreacionDePedidosEnRails7Api runtime (PostgreSQL + RabbitMQ)", :integration do
  let(:database_url) { ENV.fetch("DATABASE_URL") { raise "Integration tests need DATABASE_URL and the broker variables (see docs/RUNTIME-KERNEL.md)." } }
  let(:uid) { SecureRandom.hex(6) }
  let(:schema) { "it_#{uid}" }
  let(:topology) { RuntimeTopology.for_prefix("it-#{uid}") }
  let(:command) { "process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api" }
  let(:event) { "ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted" }
  let(:service) { CommandService.new(database_url, schema) }
  let(:broker) do
    raise "Integration tests need the broker variables (see docs/RUNTIME-KERNEL.md)." unless EventBroker.configured?

    EventBroker.connect
  end

  def count(table, where = "true", params = [])
    conn = PG.connect(database_url)
    conn.exec_params("SELECT count(*) FROM #{schema}.#{table} WHERE #{where}", params).getvalue(0, 0).to_i
  ensure
    conn&.close
  end

  # Receives and acknowledges messages until expected arrived and the source stays quiet for 0.5 s (10 s at most).
  def receive(source, expected)
    subscription = broker.subscribe(source, topology)
    out = []
    deadline = Time.now + 10
    quiet_since = Time.now
    while Time.now < deadline && (out.size < expected || Time.now - quiet_since < 0.5)
      delivery = subscription.poll
      if delivery.nil?
        sleep 0.05
        next
      end
      out << delivery.message
      delivery.ack
      quiet_since = Time.now
    end
    out
  ensure
    subscription&.close
  end

  before do
    RuntimeSchema.migrate(database_url, schema)
    broker.declare(topology)
    EXPORTER.reset
  end

  after do
    conn = PG.connect(database_url)
    conn.exec("DROP SCHEMA IF EXISTS #{schema} CASCADE")
    conn.close
    broker.close
  end

  it "IT1 persists the aggregate and one outbox row atomically; a domain error persists nothing" do
    result = service.handle(tenant_id: "t1", aggregate_id: "agg-1", command: command)
    expect([result.status, result.event_type, result.version]).to eq(["created", event, 1])
    expect(service.load("t1", "agg-1")[:version]).to eq(1)
    expect(count("ghk_outbox", "aggregate_id = $1", ["agg-1"])).to eq(1)
    expect { service.handle(tenant_id: "t1", aggregate_id: "agg-2", command: "no_such_command", idempotency_key: "k-fail") }
      .to raise_error(DomainValidationError, /Unknown command/)
    expect(service.load("t1", "agg-2")).to be_nil
    expect(count("ghk_outbox", "aggregate_id = $1", ["agg-2"])).to eq(0)
    expect(count("ghk_idempotency", "key = $1", ["k-fail"])).to eq(0)
  end

  it "IT2 five concurrent requests with one idempotency key produce one effect and identical responses" do
    results = Array.new(5) { Thread.new { service.handle(tenant_id: "t1", aggregate_id: "agg-1", command: command, idempotency_key: "key-1") } }.map(&:value)
    expect(count("ghk_outbox")).to eq(1)
    expect(service.load("t1", "agg-1")[:version]).to eq(1)
    expect(results.count { |r| r.status == "created" }).to eq(1)
    expect(results.map { |r| [r.event_type, r.version] }.uniq).to eq([[event, 1]])
  end

  it "IT3 two concurrent relays publish every outbox event exactly once" do
    20.times { |i| service.handle(tenant_id: "t1", aggregate_id: "agg-#{i}", command: command) }
    totals = %w[relay-a relay-b].map do |worker|
      Thread.new do
        publisher = broker.publisher(topology.exchange)
        relay = OutboxRelay.new(database_url, publisher, schema)
        total = 0
        while (n = relay.publish_batch(worker, 3)).positive?
          total += n
        end
        publisher.close
        total
      end
    end.map(&:value)
    expect(totals.sum).to eq(20)
    expect(count("ghk_outbox", "published_at IS NULL")).to eq(0)
    received = receive(topology.queue, 20)
    expect(received.size).to eq(20)
    expect(received.map(&:message_id).uniq.size).to eq(20)
  end

  it "IT4 tenants cannot read or change each other's aggregates" do
    service.handle(tenant_id: "tenant-a", aggregate_id: "shared-id", command: command)
    expect(service.load("tenant-b", "shared-id")).to be_nil
    service.handle(tenant_id: "tenant-b", aggregate_id: "shared-id", command: command)
    expect(service.load("tenant-a", "shared-id")[:version]).to eq(1)
    expect(service.load("tenant-b", "shared-id")[:version]).to eq(1)
    expect(count("ghk_outbox", "tenant_id = $1", ["tenant-a"])).to eq(1)
  end

  it "IT5 a failing saga step compensates the completed steps in reverse order" do
    saga = SagaOrchestrator.new(database_url, schema)
    log = []
    step = lambda do |name, fail = false|
      SagaOrchestrator::Step.new(name, -> { raise "#{name} failed" if fail; log << "do:#{name}" }, -> { log << "undo:#{name}" })
    end
    expect(saga.run("saga-1", "t1", [step.call("reserve"), step.call("charge"), step.call("ship", true)])).to eq("COMPENSATED")
    expect(log).to eq(%w[do:reserve do:charge undo:charge undo:reserve])
    expect(saga.status("saga-1")).to eq(status: "COMPENSATED", completed_steps: [])
    expect(saga.run("saga-2", "t1", [step.call("reserve"), step.call("charge")])).to eq("COMPLETED")
  end

  it "IT6 a redelivered message is handled once and a failing message is dead-lettered" do
    handled = []
    publisher = broker.publisher(topology.exchange)
    [["m-1", '{"ok": true}'], ["m-1", '{"ok": true}'], ["m-poison", '{"poison": true}']].each do |id, body|
      publisher.publish(BrokerMessage.new(message_id: id, event_type: "Test", tenant_id: "t1", body: body))
    end
    publisher.close
    subscription = broker.subscribe(topology.queue, topology)
    consumer = InboxConsumer.new(database_url, subscription, "it-consumer", schema) do |payload, meta|
      raise "cannot process" if payload["poison"]

      handled << meta[:message_id]
    end
    consumer.drain(1.0)
    subscription.close
    expect(handled).to eq(["m-1"])
    expect(count("ghk_inbox", "consumer = $1", ["it-consumer"])).to eq(1)
    expect(receive(topology.dlq, 1).map(&:message_id)).to eq(["m-poison"])
  end

  it "IT7 the incoming trace context flows through command, outbox, publish and consume spans" do
    service.handle(tenant_id: "t1", aggregate_id: "agg-1", command: command, traceparent: "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")
    conn = PG.connect(database_url)
    expect(conn.exec("SELECT traceparent FROM #{schema}.ghk_outbox").getvalue(0, 0)).to include("4bf92f3577b34da6a3ce929d0e0e4736")
    conn.close
    publisher = broker.publisher(topology.exchange)
    expect(OutboxRelay.new(database_url, publisher, schema).publish_batch("relay", 10)).to eq(1)
    publisher.close
    received = []
    subscription = broker.subscribe(topology.queue, topology)
    InboxConsumer.new(database_url, subscription, "trace-consumer", schema) { |_payload, meta| received << meta }.drain(1.0)
    subscription.close
    expect(received.size).to eq(1)

    spans = EXPORTER.finished_spans.group_by(&:kind).transform_values(&:last)
    expect(spans[:internal].hex_trace_id).to eq("4bf92f3577b34da6a3ce929d0e0e4736")
    expect(spans[:internal].hex_parent_span_id).to eq("00f067aa0ba902b7")
    expect(spans[:producer].hex_trace_id).to eq("4bf92f3577b34da6a3ce929d0e0e4736")
    expect(spans[:consumer].hex_trace_id).to eq("4bf92f3577b34da6a3ce929d0e0e4736")
    expect(spans[:consumer].hex_parent_span_id).to eq(spans[:producer].hex_span_id)
  end
end
