# frozen_string_literal: true

module Contracts
  module OrderContract
    class CreateOrderParams
      attr_reader :customer_id, :total_amount, :currency, :idempotency_key

      def initialize(customer_id:, total_amount:, currency:, idempotency_key:)
        @customer_id = customer_id
        @total_amount = total_amount
        @currency = currency
        @idempotency_key = idempotency_key
      end
    end

    interface_method :process_transaction, params: [CreateOrderParams]
    interface_method :validate_idempotency!, params: [:string]
  end
end
