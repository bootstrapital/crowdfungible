# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class EvaluateTradePolicyTool < Rubot::Tool
      description "Apply deterministic demo trading policy to a normalized request."
      idempotent!

      input_schema do
        hash :normalized_request do
          string :side, required: false
          string :symbol, required: false
          float :quantity, required: false
          float :notional_usd, required: false
          string :order_type, required: false
          array :ambiguity_flags, of: :string, required: false
        end
        hash :account do
          float :buying_power
        end
        array :positions, of: :hash, required: false do
          string :symbol
          float :quantity
          float :market_value
          float :current_price
          string :side
        end
        array :open_orders, of: :hash, required: false do
          string :symbol
          string :side
          string :order_type
          string :status
          string :order_id, required: false
          float :quantity, required: false
          float :notional_usd, required: false
        end
        hash :quote do
          boolean :available
          string :reason, required: false
        end
        hash :impact do
          boolean :impact_ready
          float :estimated_notional_usd, required: false
          float :buying_power_after, required: false
          float :post_trade_concentration_pct, required: false
        end
      end

      output_schema do
        string :decision
        array :reasons, of: :string
        array :flags, of: :string
        boolean :auto_approvable
        boolean :requires_human_approval
        boolean :hard_rejection
      end

      def call(normalized_request:, account:, positions:, open_orders:, quote:, impact:)
        reasons = []
        flags = []
        hard_rejection = false
        requires_human_approval = false

        symbol = normalized_request[:symbol].to_s.upcase
        order_type = normalized_request[:order_type].presence || "market"
        ambiguity_flags = Array(normalized_request[:ambiguity_flags])

        if symbol.present? && !CrowdFungible.symbol_allowlist.include?(symbol)
          hard_rejection = true
          flags << "unsupported_symbol"
          reasons << "#{symbol} is outside the demo symbol allowlist."
        end

        if quote[:available] == false && symbol.present? && CrowdFungible.symbol_allowlist.include?(symbol)
          hard_rejection = true
          flags << "unpriced_symbol"
          reasons << (quote[:reason].presence || "The symbol could not be priced.")
        end

        if order_type != "market"
          hard_rejection = true
          flags << "unsupported_order_type"
          reasons << "Only market orders are supported in the MVP demo."
        end

        if normalized_request[:quantity].to_f <= 0 && normalized_request[:notional_usd].to_f <= 0
          if ambiguity_flags.any?
            requires_human_approval = true
            flags << "ambiguous_size"
            reasons << "The request does not resolve to a single order size."
          else
            hard_rejection = true
            flags << "missing_order_size"
            reasons << "The request does not specify a valid quantity or dollar notional."
          end
        end

        if ambiguity_flags.any?
          requires_human_approval = true
          flags.concat(ambiguity_flags)
          reasons << "The request includes ambiguous or conditional language."
        end

        if impact[:impact_ready]
          if impact[:estimated_notional_usd].to_f > CrowdFungible.auto_approval_notional_threshold
            requires_human_approval = true
            flags << "large_notional"
            reasons << "Estimated notional exceeds the demo auto-approval threshold."
          end

          if impact[:buying_power_after].to_f < CrowdFungible.low_buying_power_threshold
            requires_human_approval = true
            flags << "low_buying_power"
            reasons << "Post-trade buying power would fall below the configured safety threshold."
          end

          if impact[:post_trade_concentration_pct].to_f > CrowdFungible.concentration_threshold
            requires_human_approval = true
            flags << "high_concentration"
            reasons << "Post-trade concentration would exceed the configured concentration threshold."
          end
        end

        if Array(open_orders).any? { |order| order[:symbol] == symbol }
          requires_human_approval = true
          flags << "open_order_conflict"
          reasons << "An open order already exists for this symbol."
        end

        decision =
          if hard_rejection
            "reject"
          elsif requires_human_approval
            "require_approval"
          else
            "execute"
          end

        {
          decision: decision,
          reasons: reasons.uniq,
          flags: flags.uniq,
          auto_approvable: decision == "execute",
          requires_human_approval: decision == "require_approval",
          hard_rejection: decision == "reject"
        }
      end
    end
  end
end
