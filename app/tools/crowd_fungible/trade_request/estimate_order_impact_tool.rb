# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class EstimateOrderImpactTool < Rubot::Tool
      description "Deterministically estimate notional, buying-power usage, and concentration."
      idempotent!

      input_schema do
        hash :normalized_request do
          string :side, required: false
          string :symbol, required: false
          float :quantity, required: false
          float :notional_usd, required: false
        end
        hash :account do
          float :buying_power
          float :portfolio_value
        end
        array :positions, of: :hash do
          string :symbol
          float :quantity
          float :market_value
          float :current_price
          string :side
        end
        hash :quote do
          boolean :available
          float :last_price, required: false
        end
      end

      output_schema do
        boolean :impact_ready
        float :estimated_notional_usd, required: false
        float :estimated_quantity, required: false
        float :buying_power_after, required: false
        float :buying_power_utilization_pct, required: false
        float :post_trade_concentration_pct, required: false
        string :notes
      end

      def call(normalized_request:, account:, positions:, quote:)
        symbol = normalized_request[:symbol]
        price = quote[:last_price].to_f
        position = Array(positions).find { |item| item[:symbol] == symbol }

        if symbol.blank? || !quote[:available] || (normalized_request[:quantity].blank? && normalized_request[:notional_usd].blank?)
          return {
            impact_ready: false,
            notes: "Impact estimate is incomplete because the request lacks a supported symbol or size."
          }
        end

        estimated_notional = normalized_request[:notional_usd].presence || (normalized_request[:quantity].to_f * price)
        estimated_quantity = normalized_request[:quantity].presence || (estimated_notional.to_f / price)
        current_position_value = position&.fetch(:market_value, 0.0).to_f
        delta_value = normalized_request[:side] == "sell" ? -estimated_notional.to_f : estimated_notional.to_f
        post_trade_position_value = [current_position_value + delta_value, 0.0].max
        buying_power_after = account.fetch(:buying_power).to_f - [delta_value, 0.0].max

        {
          impact_ready: true,
          estimated_notional_usd: estimated_notional.to_f.round(2),
          estimated_quantity: estimated_quantity.to_f.round(4),
          buying_power_after: buying_power_after.round(2),
          buying_power_utilization_pct: (estimated_notional.to_f / account.fetch(:buying_power).to_f).round(4),
          post_trade_concentration_pct: (post_trade_position_value / account.fetch(:portfolio_value).to_f).round(4),
          notes: "Estimate uses the latest available quote midpoint and current position market value."
        }
      end
    end
  end
end
