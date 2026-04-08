# CrowdFungible Architecture Notes

## Boundaries

- Host app responsibilities:
  submission UI, result UI, history UI, `TradeRequest` persistence, and user-facing status presentation.
- Rubot responsibilities:
  durable workflow execution, tool traces, approvals, replay, and operator-facing admin screens.

## Core Flow

1. The user submits a `TradeRequest` through the host app.
2. `CrowdFungible::TradeRequest::Operation` launches the Rubot workflow with the `TradeRequest` record as the run subject.
3. `CrowdFungible::TradeRequest::Workflow` normalizes the request, gathers facts, evaluates policy, asks the review agent for a bounded recommendation, and branches to reject, approval, or execution.
4. The host app syncs the persisted `TradeRequest` from the Rubot run so the product UI can show current outcome state without duplicating the admin trace surface.

## Where Logic Lives

- Broker integration:
  `app/services/crowd_fungible/broker/`
- Deterministic request parsing:
  `app/services/crowd_fungible/request_parser.rb`
- Rubot tools:
  `app/tools/crowd_fungible/trade_request/`
- Review agent:
  `app/agents/crowd_fungible/trade_request/review_agent.rb`
- Workflow and branching:
  `app/workflows/crowd_fungible/trade_request/workflow.rb`
- Product persistence and sync:
  `app/models/trade_request.rb` and `app/services/crowd_fungible/trade_request_sync.rb`

## Policy Placement

Hard rules live in `EvaluateTradePolicyTool`. The review agent can interpret and summarize, but it does not override policy or place orders directly.

## Approval Placement

Approval is part of the workflow rather than a bolt-on controller concern. That keeps approval state durable in Rubot, visible in admin, and resumable through Rubot’s normal execution model.
