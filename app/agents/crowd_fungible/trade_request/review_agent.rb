# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class ReviewAgent < Rubot::Agent
      input_schema do
        string :task
        string :request_text, required: false
        string :side, required: false
        string :symbol, required: false
        float :quantity, required: false
        float :notional_usd, required: false
        string :order_type, required: false
        hash :normalized_request, required: false
        hash :account, required: false
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
        hash :quote, required: false
        hash :impact, required: false
        hash :policy, required: false
      end

      output_schema do
        hash :normalized_request, required: false do
          string :interpreted_action, required: false
          string :side, required: false
          string :symbol, required: false
          float :quantity, required: false
          float :notional_usd, required: false
          string :order_type, required: false
          float :confidence_score, required: false
          array :ambiguity_flags, of: :string, required: false
          string :normalization_summary, required: false
        end
        string :recommendation, required: false
        string :rationale, required: false
        string :ambiguity_assessment, required: false
        string :user_facing_explanation, required: false
        string :account_impact_summary, required: false
      end

      def perform(input:, run:, context:)
        case input.fetch(:task)
        when "normalize"
          normalized = CrowdFungible::RequestParser.normalize(input)
          run.add_event(
            Rubot::Event.new(
              type: "agent.normalization.completed",
              step_name: run.current_step,
              payload: { normalized_request: normalized }
            )
          )

          { normalized_request: normalized }
        when "review"
          build_review(input)
        else
          raise CrowdFungible::PolicyError, "Unsupported review task #{input[:task]}"
        end
      end

      private

      def build_review(input)
        normalized = input.fetch(:normalized_request)
        policy = input.fetch(:policy)
        impact = input.fetch(:impact)
        account = input.fetch(:account)
        recommendation = policy.fetch(:decision)
        ambiguity_flags = Array(normalized[:ambiguity_flags])

        {
          recommendation: recommendation,
          rationale: Array(policy[:reasons]).join(" "),
          ambiguity_assessment: ambiguity_flags.any? ? "Ambiguous: #{ambiguity_flags.join(', ')}" : "Clear request.",
          user_facing_explanation: explanation_for(recommendation, normalized, policy),
          account_impact_summary: impact_summary(impact, account)
        }
      end

      def explanation_for(recommendation, normalized, policy)
        request_summary = normalized[:normalization_summary].presence || "trade request"

        case recommendation
        when "execute"
          "The system interpreted your request as #{request_summary} and policy allows immediate paper execution."
        when "require_approval"
          "The system interpreted your request as #{request_summary}, but policy requires operator review before any paper order is placed. #{Array(policy[:reasons]).join(' ')}"
        else
          "The system interpreted your request as #{request_summary}, but policy rejected it. #{Array(policy[:reasons]).join(' ')}"
        end
      end

      def impact_summary(impact, account)
        return "Impact estimate unavailable." unless impact[:impact_ready]

        "Estimated notional $#{format("%.2f", impact[:estimated_notional_usd])}, buying power after trade $#{format("%.2f", impact[:buying_power_after])}, concentration #{format("%.1f", impact[:post_trade_concentration_pct] * 100)}% of $#{format("%.2f", account[:portfolio_value])} portfolio value."
      end
    end
  end
end
