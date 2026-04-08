# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class Operation < Rubot::Operation
      tool :lookup_account, CrowdFungible::TradeRequest::LookupAccountTool
      tool :lookup_positions, CrowdFungible::TradeRequest::LookupPositionsTool
      tool :lookup_open_orders, CrowdFungible::TradeRequest::LookupOpenOrdersTool
      tool :lookup_quote, CrowdFungible::TradeRequest::LookupQuoteTool
      tool :estimate_order_impact, CrowdFungible::TradeRequest::EstimateOrderImpactTool
      tool :evaluate_trade_policy, CrowdFungible::TradeRequest::EvaluateTradePolicyTool
      tool :place_paper_order, CrowdFungible::TradeRequest::PlacePaperOrderTool

      agent :review, CrowdFungible::TradeRequest::ReviewAgent, default: true
      workflow :trade_request, CrowdFungible::TradeRequest::Workflow, default: true
      entrypoint :submit_trade_request, workflow: :trade_request
    end
  end
end
