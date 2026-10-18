# frozen_string_literal: true

# A domain event on the wire, independent of the broker.
BrokerMessage = Struct.new(:message_id, :event_type, :tenant_id, :traceparent, :body, keyword_init: true)
