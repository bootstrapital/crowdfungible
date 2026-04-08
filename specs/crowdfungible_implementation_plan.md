# CrowdFungible Implementation Plan

## Purpose

This document turns the CrowdFungible PRD into a concrete implementation plan from a fresh install.

It does not assume any particular existing app layout, sample app, or repo-specific demo structure. It treats CrowdFungible as a fresh product build on top of Rubot.

## Outcome

By the end of this plan, CrowdFungible should be a working paper-trading demo where:

- a user submits a trade request through a product UI
- the system normalizes and evaluates the request
- policy determines whether the request is auto-executed, rejected, or routed for approval
- approved trades execute against Alpaca paper trading
- every run is visible in Rubot admin with durable traces, approvals, and replayability

## Product Principles

- paper trading only
- obviously educational and demo-oriented
- policy is explicit and inspectable
- agent reasoning is useful but bounded
- execution is only allowed inside a visible policy perimeter
- the host product surface and Rubot admin surface remain clearly distinct

## Phase 0: Fresh Install and Baseline Environment

### Step 0.1: Create a new host Rails app

Generate a fresh Rails app that will host CrowdFungible.

Requirements:

- Ruby version compatible with the target Rubot release
- Rails version compatible with Rubot
- SQLite is acceptable for local development

Keep the initial app minimal. Do not add product-specific code yet.

### Step 0.2: Add Rubot to the app

Add Rubot to the Gemfile and run the install path:

```bash
bundle install
bin/rails generate rubot:install
bin/rails db:migrate
```

Confirm:

- the app boots
- the Rubot initializer exists
- Rubot tables are present
- the Rubot admin engine is mounted and reachable

### Step 0.3: Verify the clean baseline

Confirm these from a fresh app before building CrowdFungible:

- the host app root page renders
- the Rubot admin page renders
- a trivial Rubot workflow can launch and complete

### Exit Criteria

- fresh install instructions are real and repeatable
- Rubot is correctly installed in a clean host app
- admin mounting and persistence are working before product work begins

## Phase 1: Define the Product Boundary

### Step 1.1: Define the product shape

CrowdFungible should be a host application with two clear surfaces:

- product UI for submitting and tracking trade requests
- Rubot admin UI for operational oversight, approvals, replay, and traces

This split should remain visible in the architecture and in the user experience.

### Step 1.2: Define the MVP user journey

The MVP user journey is:

1. user submits a trade request
2. system interprets the request
3. system loads account and market context
4. system evaluates policy
5. system either rejects, routes for approval, or executes
6. user sees the result
7. operator can inspect the run in Rubot admin

### Step 1.3: Define the core domain language

Standardize these concepts early:

- trade request
- normalized request
- policy decision
- recommendation
- execution disposition
- approval queue
- paper order

### Step 1.4: Define user-visible statuses

Use a small, legible status set:

- `submitted`
- `executed`
- `queued_for_approval`
- `rejected`
- `failed`

### Exit Criteria

- the MVP user journey is agreed
- user-facing terms are stable
- the product/admin split is explicitly defined

## Phase 2: Define the System Architecture

### Step 2.1: Define the Rubot operation boundary

Create a top-level operation for the trade-request capability.

Recommended shape:

- `CrowdFungible::TradeRequest::Operation`

Responsibilities:

- register the workflow
- register the review agent
- register the tools used by the workflow
- expose the application entrypoint for launching a trade-request run

### Step 2.2: Define the workflow boundary

Create a single MVP workflow for trade request handling.

Recommended shape:

- `CrowdFungible::TradeRequest::Workflow`

Responsibilities:

- orchestrate normalization
- gather account and market facts
- run policy evaluation
- call the review agent
- branch to reject, approval, or execution
- finalize the run output

### Step 2.3: Define the agent boundary

Create one bounded review agent.

Recommended shape:

- `CrowdFungible::TradeRequest::ReviewAgent`

Responsibilities:

- interpret ambiguous phrasing into a structured request
- summarize account impact
- reason over facts and policy output
- recommend `execute`, `require_approval`, or `reject`

The agent should not define hard safety rules.

### Step 2.4: Define the tool boundary

Keep tools explicit and inspectable.

Initial tool set:

- `LookupAccountTool`
- `LookupPositionsTool`
- `LookupOpenOrdersTool`
- `LookupQuoteTool`
- `EstimateOrderImpactTool`
- `EvaluateTradePolicyTool`
- `PlacePaperOrderTool`

### Exit Criteria

- operation, workflow, agent, and tool responsibilities are clearly separated
- workflow branching is designed before implementation starts

## Phase 3: Define the Data Contracts

### Step 3.1: Define workflow input

The workflow input should support both freeform and structured trade entry.

Suggested input fields:

- `request_text`
- `side`
- `symbol`
- `quantity`
- `notional_usd`
- `order_type`
- `submitted_by`

Structured fields should be optional so the system can demonstrate interpretation of plain-language requests.

### Step 3.2: Define normalized request output

The normalized request should include:

- interpreted action
- symbol
- quantity or notional
- order type
- confidence score
- ambiguity flags
- normalization summary

### Step 3.3: Define policy output

Policy output should include:

- `decision`
- `reasons`
- `flags`
- `auto_approvable`
- `requires_human_approval`
- `hard_rejection`

### Step 3.4: Define final workflow output

The final run output should include:

- original request
- normalized request
- account and quote summary
- policy result
- recommendation
- final disposition
- execution result if applicable
- human approval result if applicable

### Exit Criteria

- input and output contracts are explicit before UI or tool work proceeds

## Phase 4: Set Up External Integrations

### Step 4.1: Add Alpaca paper trading configuration

Add environment configuration for:

- Alpaca API key
- Alpaca secret key
- Alpaca paper trading base URL

Also add demo configuration for:

- auto-approval notional threshold
- concentration threshold
- low-buying-power threshold
- symbol allowlist

### Step 4.2: Create a broker integration layer

Build a thin Alpaca client wrapper that:

- uses `Rubot::HTTP`
- centralizes authentication
- normalizes response shapes
- normalizes API errors

Keep Alpaca-specific request details out of workflow and tool code.

### Step 4.3: Define the MVP market-data scope

Limit MVP context gathering to:

- account buying power
- current positions
- open orders
- latest quote or latest trade

Do not add historical strategy features or advanced order support in MVP.

### Exit Criteria

- external brokerage access is isolated behind one client boundary
- env configuration is documented
- MVP integration scope is intentionally constrained

## Phase 5: Implement Fact-Gathering Tools

### Step 5.1: Implement account and position tools

Build:

- `LookupAccountTool`
- `LookupPositionsTool`
- `LookupOpenOrdersTool`

These should return compact, structured facts that are easy to inspect in traces.

### Step 5.2: Implement quote lookup

Build:

- `LookupQuoteTool`

Responsibilities:

- validate the symbol
- load price context needed for policy and execution summaries

### Step 5.3: Implement order impact estimation

Build:

- `EstimateOrderImpactTool`

Responsibilities:

- estimate trade notional
- compare order size against buying power
- estimate post-trade concentration

Keep this deterministic and explainable.

### Exit Criteria

- all facts required for policy evaluation can be gathered without agent invention

## Phase 6: Implement Policy Evaluation

### Step 6.1: Create a deterministic policy tool

Build:

- `EvaluateTradePolicyTool`

The policy layer should be the source of hard constraints.

### Step 6.2: Encode MVP rules

First-pass rules should include:

- reject invalid or unsupported symbols
- reject unsupported order types
- reject requests outside demo-safe boundaries
- require approval for ambiguous requests
- require approval for large notionals
- require approval for tight buying power
- require approval for excessive concentration
- require approval for open-order conflicts
- auto-approve only small, clear market orders with sufficient buying power and no flags

### Step 6.3: Make policy visible in the product story

Ensure policy outputs are easy to show in:

- final user-facing results
- Rubot admin traces
- approval review screens

### Exit Criteria

- policy outcomes are deterministic
- hard rules live in policy, not in the agent prompt

## Phase 7: Implement Request Normalization and Review

### Step 7.1: Implement normalization behavior

Use the review agent to interpret freeform requests into a strict structured format.

Examples:

- "Buy 10 shares of AAPL"
- "Sell half the TSLA position"
- "Put $500 into NVDA if cash is available"

### Step 7.2: Bound the agent’s role

The review agent may:

- interpret intent
- summarize facts
- recommend a path

The review agent may not:

- override hard policy rejections
- invent broker state
- execute trades directly

### Step 7.3: Define the review output

Review output should include:

- recommendation
- rationale
- ambiguity assessment
- user-facing explanation
- account-impact summary

### Exit Criteria

- ambiguous phrasing becomes structured and inspectable
- the agent role is clearly bounded by policy and workflow

## Phase 8: Implement the Workflow and Branching

### Step 8.1: Build the workflow sequence

Recommended step sequence:

1. normalize request
2. lookup account
3. lookup positions
4. lookup open orders
5. lookup quote
6. estimate order impact
7. evaluate policy
8. review via agent
9. branch to reject, approval, or execution
10. finalize output

### Step 8.2: Add approval branching

Use Rubot approval steps for cases that require human review.

Approval payload should preserve:

- normalized request
- policy flags and reasons
- impact estimate
- recommendation summary

### Step 8.3: Add rejection branching

Reject early when policy returns a hard rejection.

The final output should still explain:

- what the user requested
- how the system interpreted it
- why the request was rejected

### Step 8.4: Add execution branching

Only allow execution when:

- policy permits execution
- no unresolved ambiguity remains
- workflow has either auto-approved or received human approval

### Exit Criteria

- the workflow can reach all three core outcomes
- approval is a first-class workflow branch

## Phase 9: Implement Paper Order Execution

### Step 9.1: Build the execution tool

Implement:

- `PlacePaperOrderTool`

Responsibilities:

- translate normalized requests into Alpaca order payloads
- submit paper orders only
- return normalized execution results

### Step 9.2: Add execution guardrails

Before placing an order, ensure:

- the workflow disposition allows execution
- the order shape matches MVP-safe constraints
- execution is only targeting Alpaca paper endpoints

### Step 9.3: Make execution outcomes legible

Execution output should show:

- order submitted or not
- broker-side status
- order identifiers
- user-facing execution summary

### Exit Criteria

- only approved requests can reach execution
- execution results are easy to inspect in both product UI and Rubot admin

## Phase 10: Build the Product UI

### Step 10.1: Build the submission page

The submission page should allow:

- freeform request entry
- optional structured fields
- clear disclaimer that this is paper trading only
- brief explanation of possible outcomes

### Step 10.2: Build the result page

The result page should show:

- current status
- normalized request
- policy flags
- recommendation
- final disposition
- execution summary if applicable
- link into the Rubot admin run when available

### Step 10.3: Build a lightweight request history view

Allow users to review recent requests and their outcomes.

Keep this page simple. It only needs to reinforce the product story.

### Exit Criteria

- a first-time user can submit a request and understand the outcome without opening the admin UI

## Phase 11: Make the Admin Experience Demo-Ready

### Step 11.1: Ensure traces read cleanly

Review the run timeline so it is easy to explain live.

Focus on:

- concise step names
- compact tool outputs
- visible policy reasoning
- visible approval state

### Step 11.2: Validate approval operations

Ensure an operator can:

- find queued requests
- inspect context
- approve or reject clearly

### Step 11.3: Validate replay usefulness

Ensure replay is valuable for:

- ambiguous requests
- policy-driven escalations
- debugging rejected or executed outcomes

### Exit Criteria

- the Rubot admin surface tells a coherent operational story in demos

## Phase 12: Testing and Reliability

### Step 12.1: Add tool tests

Cover:

- Alpaca client normalization
- account and quote tool outputs
- order impact calculations
- execution payload shaping

### Step 12.2: Add policy tests

Cover:

- valid small order auto-approval
- oversized order approval requirement
- invalid symbol rejection
- tight buying power escalation
- open-order conflict escalation

### Step 12.3: Add workflow tests

Cover:

- clear small buy executes
- large request routes to approval
- invalid request rejects
- ambiguous request routes to approval
- approval resume leads to execution

### Step 12.4: Add UI smoke coverage

Cover:

- submission page renders
- request submission launches a Rubot run
- result page renders the final status

Mock external broker calls in tests. Do not rely on live Alpaca access for regression coverage.

### Exit Criteria

- all core decision paths have automated coverage
- demo-critical paths are not dependent on manual testing alone

## Phase 13: Documentation and Launch Readiness

### Step 13.1: Write local setup instructions

Document:

- required environment variables
- how to install and boot the app from scratch
- how to get Alpaca paper credentials
- how to run the product locally

### Step 13.2: Write demo instructions

Document canonical demo scenarios:

- small clear buy that auto-executes
- ambiguous request that routes to approval
- invalid symbol that rejects
- oversized order that requires approval

### Step 13.3: Write architecture notes

Explain:

- what belongs in the host app
- what belongs in Rubot
- where policy lives
- where broker integration lives
- why approval is part of the workflow instead of bolted on later

### Exit Criteria

- a new developer can set up and demo CrowdFungible from documentation alone

## Recommended Build Order

Implement in this order:

1. fresh install and Rubot baseline
2. product boundary and data contracts
3. Alpaca client and environment configuration
4. fact-gathering tools
5. policy tool
6. review agent
7. workflow branching and approvals
8. execution tool
9. product UI
10. tests
11. documentation and demo polish

## MVP Acceptance Checklist

MVP is complete when:

- a fresh Rails app can install Rubot and boot successfully
- CrowdFungible can launch a trade-request workflow from the product UI
- freeform requests can be normalized into structured trade intent
- account and quote context are gathered through explicit tools
- policy visibly determines reject versus approval versus execution eligibility
- some requests auto-execute against Alpaca paper trading
- some requests queue for approval
- some requests reject with clear reasons
- the final user-facing result explains what happened
- the Rubot admin trace is clear enough for a live demo
- the core paths are regression-covered

## Post-MVP Enhancements

After MVP, consider:

- offline fake-broker mode for demos without network dependencies
- richer market-hours logic
- more expressive order types
- account personas or seeded portfolios
- improved approval inbox presentation for trading review
- richer request history and portfolio views
