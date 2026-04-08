# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class PlacePaperOrderTool < Rubot::Tool
      description "Submit a paper order through the configured broker client."

      input_schema do
        hash :normalized_request do
          string :side
          string :symbol
          float :quantity, required: false
          float :notional_usd, required: false
          string :order_type
        end
        hash :policy do
          string :decision
        end
      end

      output_schema do
        string :order_id
        string :broker_status
        string :symbol
        string :side
        float :quantity, required: false
        float :notional_usd, required: false
        string :order_type
        float :filled_avg_price, required: false
        string :submitted_at
        boolean :paper
      end

      def call(normalized_request:, policy:)
        raise CrowdFungible::PolicyError, "Execution is not permitted for this request." unless policy[:decision] == "execute"
        raise CrowdFungible::PolicyError, "Only market orders are supported for execution." unless normalized_request[:order_type] == "market"
        raise CrowdFungible::PolicyError, "Requested symbol is outside the demo allowlist." unless CrowdFungible.symbol_allowlist.include?(normalized_request[:symbol].to_s.upcase)

        broker.place_order(
          order: {
            symbol: normalized_request.fetch(:symbol).upcase,
            side: normalized_request.fetch(:side),
            quantity: normalized_request[:quantity]&.to_f,
            notional_usd: normalized_request[:notional_usd]&.to_f,
            order_type: normalized_request.fetch(:order_type)
          }
        )
      end

      private

      def broker
        CrowdFungible::Broker::Client.build
      end
    end
  end
end
