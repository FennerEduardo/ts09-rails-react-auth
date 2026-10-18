# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

# Google Cloud Pub/Sub over its REST API (no client library): topics for the exchange and the DLX, pull subscriptions
# for the queue and the DLQ. publish returns once Pub/Sub has stored the message. A failed message is dead-lettered by
# the consumer: published to the DLX topic, then acknowledged.
# Auth: none against the emulator (PUBSUB_EMULATOR_HOST); otherwise GOOGLE_OAUTH_ACCESS_TOKEN or the metadata-server
# token of the workload's service account (Cloud Run, GKE workload identity).
class PubSubBroker
  METADATA_TOKEN = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"

  def self.from_env
    project = EventBroker.env("PUBSUB_PROJECT_ID") || EventBroker.env("GOOGLE_CLOUD_PROJECT") ||
              raise("PUBSUB_PROJECT_ID (or GOOGLE_CLOUD_PROJECT) is not set")
    new(project, EventBroker.env("PUBSUB_EMULATOR_HOST"))
  end

  def initialize(project, emulator_host = nil)
    @project = project
    @emulator = !emulator_host.nil?
    @root = "#{@emulator ? "http://#{emulator_host}" : "https://pubsub.googleapis.com"}/v1/projects/#{project}"
    @lock = Mutex.new
  end

  def system = "gcp_pubsub"
  def dynamic_topology? = true
  def close; end

  def declare(topology)
    # 409: it already exists (created earlier or by infrastructure as code).
    call(:put, "/topics/#{topology.exchange}", {}, accepted: [409])
    call(:put, "/topics/#{topology.dlx}", {}, accepted: [409])
    call(:put, "/subscriptions/#{topology.queue}", { topic: "projects/#{@project}/topics/#{topology.exchange}", ackDeadlineSeconds: 60 }, accepted: [409])
    call(:put, "/subscriptions/#{topology.dlq}", { topic: "projects/#{@project}/topics/#{topology.dlx}", ackDeadlineSeconds: 60 }, accepted: [409])
  end

  def publisher(topic)
    Publisher.new(self, topic)
  end

  def subscribe(subscription, topology)
    Subscription.new(self, subscription, topology)
  end

  def publish_to(topic, message)
    attributes = { "ghk_message_id" => message.message_id }
    attributes["event_type"] = message.event_type if message.event_type
    attributes["tenant_id"] = message.tenant_id if message.tenant_id
    attributes["traceparent"] = message.traceparent if message.traceparent
    res = call(:post, "/topics/#{topic}:publish", { messages: [{ data: [message.body].pack("m0"), attributes: attributes }] })
    raise "Pub/Sub did not accept message #{message.message_id}" unless res&.dig("messageIds")&.size == 1
  end

  # Calls the API; a status listed in accepted returns nil instead of failing.
  def call(method, path, body = nil, accepted: [])
    uri = URI("#{@root}#{path}")
    request = (method == :put ? Net::HTTP::Put : Net::HTTP::Post).new(uri, "Content-Type" => "application/json")
    request.body = JSON.generate(body) unless body.nil?
    token = bearer
    request["Authorization"] = "Bearer #{token}" if token
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 30) { |http| http.request(request) }
    code = response.code.to_i
    return (response.body.to_s.strip.empty? ? {} : JSON.parse(response.body)) if code.between?(200, 299)
    return nil if accepted.include?(code)

    raise "Pub/Sub #{method.upcase} #{path} failed: #{code} #{response.body}"
  end

  private

  def bearer
    return nil if @emulator
    return EventBroker.env("GOOGLE_OAUTH_ACCESS_TOKEN") if EventBroker.env("GOOGLE_OAUTH_ACCESS_TOKEN")

    @lock.synchronize do
      if @token.nil? || Time.now > @expires_at
        uri = URI(METADATA_TOKEN)
        body = Net::HTTP.start(uri.host, uri.port, read_timeout: 5) { |http| http.get(uri.path, "Metadata-Flavor" => "Google") }.body
        data = JSON.parse(body)
        @token = data.fetch("access_token")
        @expires_at = Time.now + data.fetch("expires_in").to_i - 60
      end
      @token
    end
  end

  class Publisher
    attr_reader :destination

    def initialize(broker, topic)
      @broker = broker
      @destination = topic
    end

    def system = "gcp_pubsub"

    def publish(message)
      @broker.publish_to(@destination, message)
    end

    def close; end
  end

  class Subscription
    attr_reader :source

    def initialize(broker, subscription, topology)
      @broker = broker
      @source = subscription
      @topology = topology
    end

    def system = "gcp_pubsub"

    def poll
      res = @broker.call(:post, "/subscriptions/#{@source}:pull", { maxMessages: 1, returnImmediately: true }) || {}
      first = (res["receivedMessages"] || []).first
      return nil if first.nil?

      msg = first["message"]
      attrs = msg["attributes"] || {}
      message = BrokerMessage.new(message_id: attrs["ghk_message_id"] || msg["messageId"], event_type: attrs["event_type"], tenant_id: attrs["tenant_id"],
                                  traceparent: attrs["traceparent"], body: msg.fetch("data", "").unpack1("m"))
      ack = -> { @broker.call(:post, "/subscriptions/#{@source}:acknowledge", { ackIds: [first["ackId"]] }) }
      BrokerDelivery.new(message, ack, lambda {
        @broker.publish_to(@topology.dlx, message)
        ack.call
      })
    end

    def close; end
  end
end
