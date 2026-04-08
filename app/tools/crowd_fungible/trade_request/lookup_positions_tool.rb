# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class LookupPositionsTool < Rubot::Tool
      description "Load current paper positions for concentration and sell checks."
      idempotent!

      output_schema do
        array :positions, of: :hash do
          string :symbol
          float :quantity
          float :market_value
          float :current_price
          string :side
        end
      end

      def call(**)
        { positions: broker.positions }
      end

      private

      def broker
        CrowdFungible::Broker::Client.build
      end
    end
  end
end
