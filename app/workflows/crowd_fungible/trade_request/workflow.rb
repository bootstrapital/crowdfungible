# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class Workflow < Rubot::Workflow
      agent_step :normalize_request,
                 agent: CrowdFungible::TradeRequest::ReviewAgent,
                 input: lambda { |input, _state, _context|
                   {
                     task: "normalize",
                     request_text: input[:request_text],
                     side: input[:side],
                     symbol: input[:symbol],
                     quantity: input[:quantity]&.to_f,
                     notional_usd: input[:notional_usd]&.to_f,
                     order_type: input[:order_type]
                   }
                 },
                 save_as: :normalized_request

      tool_step :resolve_company_symbol,
                tool: CrowdFungible::TradeRequest::ResolveCompanySymbolTool,
                input: lambda { |input, state, _context|
                  {
                    request_text: input[:request_text],
                    normalized_request: state.fetch(:normalized_request).fetch(:normalized_request)
                  }
                },
                save_as: :resolved_request

      tool_step :lookup_account,
                tool: CrowdFungible::TradeRequest::LookupAccountTool

      tool_step :lookup_positions,
                tool: CrowdFungible::TradeRequest::LookupPositionsTool,
                input: {}

      tool_step :lookup_open_orders,
                tool: CrowdFungible::TradeRequest::LookupOpenOrdersTool,
                input: {}

      tool_step :lookup_quote,
                tool: CrowdFungible::TradeRequest::LookupQuoteTool,
                input: ->(_input, state, _context) { { normalized_request: CrowdFungible::TradeRequest::Workflow.resolved_request(state) } }

      tool_step :estimate_order_impact,
                tool: CrowdFungible::TradeRequest::EstimateOrderImpactTool,
                input: lambda { |_input, state, _context|
                  {
                    normalized_request: CrowdFungible::TradeRequest::Workflow.resolved_request(state),
                    account: state.fetch(:lookup_account),
                    positions: state.fetch(:lookup_positions).fetch(:positions),
                    quote: state.fetch(:lookup_quote)
                  }
                }

      tool_step :evaluate_trade_policy,
                tool: CrowdFungible::TradeRequest::EvaluateTradePolicyTool,
                input: lambda { |_input, state, _context|
                  {
                    normalized_request: CrowdFungible::TradeRequest::Workflow.resolved_request(state),
                    account: state.fetch(:lookup_account),
                    positions: state.fetch(:lookup_positions).fetch(:positions),
                    open_orders: state.fetch(:lookup_open_orders).fetch(:open_orders),
                    quote: state.fetch(:lookup_quote),
                    impact: state.fetch(:estimate_order_impact)
                  }
                }

      agent_step :review_request,
                 agent: CrowdFungible::TradeRequest::ReviewAgent,
                 input: lambda { |input, state, _context|
                  {
                     task: "review",
                     request_text: input[:request_text],
                     normalized_request: CrowdFungible::TradeRequest::Workflow.resolved_request(state),
                     account: state.fetch(:lookup_account),
                     positions: state.fetch(:lookup_positions).fetch(:positions),
                     open_orders: state.fetch(:lookup_open_orders).fetch(:open_orders),
                     quote: state.fetch(:lookup_quote),
                     impact: state.fetch(:estimate_order_impact),
                     policy: state.fetch(:evaluate_trade_policy)
                   }
                 },
                 save_as: :review_request

      step :prepare_approval_packet, if: :approval_required?
      step :finalize_rejection, if: :rejection?

      approval_step :human_approval,
                    role: "trade_operator",
                    reason: "Trade request requires human review.",
                    if: :approval_required?

      step :capture_approval_result, if: :approval_required?

      tool_step :execute_order,
                tool: CrowdFungible::TradeRequest::PlacePaperOrderTool,
                input: lambda { |_input, state, _context|
                  {
                    normalized_request: CrowdFungible::TradeRequest::Workflow.resolved_request(state),
                    policy: state.fetch(:evaluate_trade_policy).merge(decision: "execute")
                  }
                },
                if: :execution_permitted?

      step :finalize_result

      output :finalize_result

      def rejection?
        policy.fetch(:decision) == "reject"
      end

      def approval_required?
        policy.fetch(:decision) == "require_approval"
      end

      def execution_permitted?
        return false if unresolved_ambiguity?
        return true if policy.fetch(:decision) == "execute"

        approval_required? && run.approvals.last&.status == :approved
      end

      def prepare_approval_packet
        run.state[:approval_packet] = {
          normalized_request: resolved_request(run.state),
          policy: run.state.fetch(:evaluate_trade_policy),
          impact: run.state.fetch(:estimate_order_impact),
          recommendation: run.state.fetch(:review_request)
        }
      end

      def finalize_rejection
        run.state[:rejection_result] = {
          final_disposition: "rejected",
          rejected_at: Time.current.iso8601,
          reasons: policy.fetch(:reasons),
          explanation: run.state.fetch(:review_request).fetch(:user_facing_explanation)
        }
      end

      def capture_approval_result
        approval = run.approvals.last
        return unless approval&.status == :approved

        run.state[:approval_result] = {
          status: "approved",
          approved_by: approval.decision_payload[:approved_by],
          note: approval.decision_payload[:note]
        }
      end

      def finalize_result
        run.state[:finalize_result] = {
          original_request: run.input.slice(:request_text, :side, :symbol, :quantity, :notional_usd, :order_type, :submitted_by),
          normalized_request: resolved_request(run.state),
          account_summary: run.state.fetch(:lookup_account),
          quote_summary: run.state.fetch(:lookup_quote),
          policy_result: run.state.fetch(:evaluate_trade_policy),
          recommendation: run.state.fetch(:review_request),
          final_disposition: final_disposition,
          execution_result: run.state[:execute_order],
          human_approval_result: run.state[:approval_result]
        }
      end

      private

      def policy
        run.state.fetch(:evaluate_trade_policy)
      end

      def final_disposition
        return "rejected" if rejection?
        return "executed" if run.state[:execute_order].present?
        return "queued_for_approval" if run.waiting_for_approval?

        "failed"
      end

      def unresolved_ambiguity?
        Array(resolved_request(run.state)[:ambiguity_flags]).any?
      end

      def self.resolved_request(state)
        state[:resolved_request].presence || state.fetch(:normalized_request).fetch(:normalized_request)
      end

      def resolved_request(state)
        self.class.resolved_request(state)
      end
    end
  end
end
