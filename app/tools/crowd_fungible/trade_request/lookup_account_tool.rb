# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class LookupAccountTool < Rubot::Tool
      description "Load a compact account summary for paper trading policy checks."
      idempotent!

      output_schema do
        string :account_id
        float :buying_power
        float :cash
        float :portfolio_value
        string :currency
        string :status
      end

      def call(**)
        broker.account
      end

      private

      def broker
        CrowdFungible::Broker::Client.build
      end
    end
  end
end
