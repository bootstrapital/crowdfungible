# CrowdFungible PRD

## Purpose

CrowdFungible is a playful demo product built on Rubot.

It should showcase how Rubot can power a real-looking agentic application with:

- a user-facing product surface
- real external API tools
- agent reasoning
- approvals and routing
- durable execution traces
- a clear admin/workbench story

This is not meant to be a production trading system.
It is a compelling explainer app that makes the Rubot architecture legible.

## Product Concept

CrowdFungible lets users submit trade requests against a paper trading account.

Those requests are then:

- interpreted and normalized
- checked against current account and market context
- evaluated against explicit trading policies
- approved automatically or routed to a human
- executed against Alpaca paper trading
- recorded as durable Rubot runs with full traceability

The core idea is:

“What if people could submit trade requests, and an agentic workflow decided whether to execute them automatically or send them to a human release queue?”

## Goals

### Primary Goal

Build a memorable, understandable Rubot demo that shows the framework doing real work with meaningful controls.

### Secondary Goals

- demonstrate the host-app + admin-engine architecture
- demonstrate external API tools
- demonstrate approval routing
- demonstrate replay and trace inspection
- provide a reusable demo for talks, docs, and investor/customer conversations

## Non-Goals

- real-money trading
- investment advice
- autonomous portfolio management
- advanced quant or strategy features
- regulatory-grade brokerage workflows

This project should remain obviously playful, educational, and paper-trading-only.

## User Story

As a user, I can submit a trade request such as:

- “Buy 10 shares of AAPL”
- “Sell half the TSLA position”
- “Put $500 into NVDA if cash is available”

The system should:

- understand what I meant
- gather account and quote context
- assess whether the request is safe/clear enough to auto-execute
- either place the paper trade or route it for manual approval
- show me the outcome and status

## Why This Is a Good Rubot Demo

CrowdFungible shows off several Rubot strengths at once:

- agent reasoning is useful but bounded
- tools are explicit and auditable
- approval routing feels natural
- run traces matter
- external APIs are involved
- the operator/admin experience is important

It is more compelling than a generic chatbot because:

- there is a concrete action at stake
- there is a visible distinction between recommendation and execution
- risk controls and approvals are intuitive

## Target Experience

### User-Facing Surface

The product-facing app should let users:

- submit a trade request
- optionally choose a side, ticker, quantity, or notional amount
- see request status
- see whether the request was auto-executed, rejected, or routed for approval
- see the normalized interpretation of their request

### Operator/Admin Surface

The Rubot admin engine should let the operator:

- inspect the run
- review the reasoning trace
- see tool calls and market/account context
- approve or reject queued requests
- replay a run for debugging

This split is important:

- host app = fun demo product
- Rubot admin = operational oversight surface

## Core Workflow

The first MVP workflow should likely be:

1. receive trade request
2. normalize request intent
3. load quote/account/position context
4. evaluate policy constraints
5. generate execution recommendation
5. branch:
   - auto-approve and execute
   - require human approval
   - reject
6. place paper order if approved
7. finalize result

## Rubot Architecture

### Operation

Example:

- `CrowdFungible::TradeRequest::Operation`

This should act as the feature boundary for the trade-request flow.

### Workflow

Example:

- `CrowdFungible::TradeRequest::Workflow`

This should orchestrate:

- request normalization
- context gathering
- policy evaluation
- recommendation
- approval branch
- execution

### Agent

Example:

- `CrowdFungible::TradeRequest::ReviewAgent`

This agent should:

- interpret ambiguous user phrasing
- reason over policy results and risk context
- produce a normalized request
- summarize account impact
- recommend one of:
  - execute
  - require approval
  - reject

### Tools

Likely tool set:

- `LookupAccountTool`
- `LookupPositionsTool`
- `LookupQuoteTool`
- `NormalizeTradeRequestTool` or agent-only normalization
- `EstimateOrderImpactTool`
- `EvaluateTradePolicyTool`
- `PlacePaperOrderTool`
- `LookupOpenOrdersTool`

## Policy Layer

CrowdFungible should make policy visible as part of the decision flow, not just as hidden implementation detail.

The workflow should explicitly evaluate trade policies before the final recommendation is made.

That policy pass can produce structured outputs like:

- `allowed`
- `requires_approval`
- `rejected`
- policy reasons
- policy flags

This helps demonstrate an important Rubot idea:

- tools gather facts
- policies express hard constraints and safety rules
- agents reason over facts plus policy outcomes
- workflows decide what path to take

In the demo, the agent should not appear to be inventing risk rules on its own.
It should be shown operating within a policy boundary.

## Approval Strategy

The demo becomes much more interesting if only some requests auto-execute.

Examples of approval-worthy cases:

- large notional size
- low available cash
- ambiguous ticker or malformed request
- outsized concentration in one symbol
- trade conflicts with open orders
- after-hours or unusual order conditions

Examples of hard policy rejection:

- invalid or unsupported symbol
- insufficient buying power beyond configured tolerance
- prohibited order types
- requests outside demo-safe account rules

Examples of auto-approval cases:

- small, clear buy/sell requests
- liquid symbols
- simple market orders under a defined threshold

## Suggested MVP Rules

Keep the rules simple and visible.

Possible first-pass logic:

- auto-approve when:
  - symbol is recognized
  - request is unambiguous
  - market order is below a small notional threshold
  - sufficient buying power exists
  - no policy flags require escalation

- require approval when:
  - request is ambiguous
  - order exceeds threshold
  - order would materially concentrate the account
  - buying power is tight
  - policy evaluation returns `requires_approval`

- reject when:
  - ticker is invalid
  - request cannot be normalized confidently
  - order is structurally invalid
  - policy evaluation returns `rejected`

## UI Surfaces

### Product UI

Suggested pages:

- home / landing page
- trade request form
- request result page
- user-visible run detail or status page

The tone can be fun and light.
The implementation should still reflect the normal Rubot host-app pattern.

### Admin UI

Use the existing Rubot admin engine for:

- runs
- approvals
- replay
- trace inspection

This is part of the point of the demo: show that the framework already provides the operational side.

## Technical Integrations

### Alpaca

Use Alpaca paper trading only.

Likely needs:

- paper account API key
- paper trading account configuration
- quote/account/order endpoints

### Safety Constraints

The app should make the following explicit:

- paper trading only
- not financial advice
- demo/educational project
- execution rules are heuristic and for showcase purposes

## MVP Deliverables

- Rails host app surface for submitting trade requests
- Rubot operation/workflow/agent/tools for request handling
- explicit policy evaluation in the workflow decision path
- Alpaca paper-trading integration
- approval routing for some requests
- admin trace visibility through Rubot
- basic demo-safe copy and disclaimers

## Success Criteria

CrowdFungible is successful as a demo if a viewer can understand, within a few minutes:

- what the user is asking the system to do
- where agent reasoning happens
- where tools are used
- where policy constraints are applied
- why some requests need approval
- how Rubot records and exposes the full run

In other words, it should make Rubot feel concrete.

## Nice-to-Have Later

- leaderboard or activity feed
- crowd voting or “would you approve this?” interactions
- delayed execution windows
- richer order types
- portfolio snapshots
- social/demo mechanics for sharing requests

These are optional.
The first version should stay tightly scoped around trade-request intake, review, approval, and paper execution.

## Summary

CrowdFungible should be a high-signal Rubot showcase:

- easy to understand
- fun enough to remember
- serious enough to demonstrate real architecture

It should highlight the core Rubot story:

- app-facing UI in Rails
- agentic workflow execution in Rubot
- explicit tool usage
- explicit policy boundaries
- human approval where appropriate
- admin-grade traces and governance
