# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class LookupOpenOrdersTool < Rubot::Tool
      description "Load open paper orders to flag conflicting activity."
      idempotent!

      output_schema do
        array :open_orders, of: :hash do
          string :order_id, required: false
          string :symbol
          string :side
          float :quantity, required: false
          float :notional_usd, required: false
          string :order_type
          string :status
        end
      end

      def call(**)
        { open_orders: broker.open_orders }
      end

      private

      def broker
        CrowdFungible::Broker::Client.build
      end
    end
  end
end
