# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class LookupQuoteTool < Rubot::Tool
      description "Load latest quote context for the requested symbol."
      idempotent!

      input_schema do
        hash :normalized_request do
          string :symbol, required: false
        end
      end

      output_schema do
        string :symbol, required: false
        boolean :available
        float :bid_price, required: false
        float :ask_price, required: false
        float :last_price, required: false
        string :source, required: false
        string :reason, required: false
      end

      def call(normalized_request:)
        symbol = normalized_request[:symbol].to_s.upcase
        return { available: false, reason: "No symbol provided." } if symbol.blank?
        return { symbol:, available: false, reason: "Symbol is outside the demo allowlist." } unless CrowdFungible.symbol_allowlist.include?(symbol)

        broker.quote(symbol:).merge(available: true)
      rescue CrowdFungible::BrokerError => e
        { symbol:, available: false, reason: e.message }
      end

      private

      def broker
        CrowdFungible::Broker::Client.build
      end
    end
  end
end
