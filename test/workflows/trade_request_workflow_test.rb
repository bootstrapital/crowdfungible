# frozen_string_literal: true

require "test_helper"

class TradeRequestWorkflowTest < ActiveSupport::TestCase
  test "clear small buy executes" do
    run = launch("Buy 2 shares of AAPL")

    assert_equal :completed, run.status
    assert_equal "executed", run.output[:final_disposition]
    assert_equal "execute", run.output.dig(:policy_result, :decision)
  end

  test "allowlisted company name resolves to ticker and executes" do
    run = launch("Buy 2 shares of Apple")

    assert_equal :completed, run.status
    assert_equal "executed", run.output[:final_disposition]
    assert_equal "AAPL", run.output.dig(:normalized_request, :symbol)
    assert_equal "apple", run.output.dig(:normalized_request, :resolved_from_company_alias)
  end

  test "single-share company alias request executes" do
    run = launch("Buy a share of Visa")

    assert_equal :completed, run.status
    assert_equal "executed", run.output[:final_disposition]
    assert_equal "V", run.output.dig(:normalized_request, :symbol)
    assert_equal 1.0, run.output.dig(:normalized_request, :quantity)
    assert_equal "visa", run.output.dig(:normalized_request, :resolved_from_company_alias)
  end

  test "large request routes to approval" do
    run = launch("Buy $25000 of NVDA")

    assert_equal :waiting_for_approval, run.status
    assert_equal "require_approval", run.state.dig(:evaluate_trade_policy, :decision)
  end

  test "invalid symbol rejects" do
    run = launch("Buy 5 shares of ZZZZ")

    assert_equal :completed, run.status
    assert_equal "rejected", run.output[:final_disposition]
    assert_equal "reject", run.output.dig(:policy_result, :decision)
  end

  test "unsupported company name rejects" do
    run = launch("Buy 5 shares of Netflix")

    assert_equal :completed, run.status
    assert_equal "rejected", run.output[:final_disposition]
    assert_equal "reject", run.output.dig(:policy_result, :decision)
    assert_equal "Netflix", run.output.dig(:normalized_request, :requested_company_name)
    assert_includes run.output.dig(:policy_result, :flags), "unsupported_company_name"
  end

  test "ambiguous request routes to approval" do
    run = launch("Put $500 into NVDA if cash is available")

    assert_equal :waiting_for_approval, run.status
    assert_equal "require_approval", run.state.dig(:evaluate_trade_policy, :decision)
  end

  test "approval resume leads to execution" do
    run = launch("Buy $25000 of NVDA")

    run.approve!(approved_by: "ops@example.com", note: "Reviewed")
    Rubot::Executor.new.resume(CrowdFungible::TradeRequest::Workflow, run)

    assert_equal :completed, run.status
    assert_equal "executed", run.output[:final_disposition]
    assert_equal "approved", run.state.dig(:approval_result, :status)
  end

  private

  def launch(request_text)
    CrowdFungible::TradeRequest::Operation.launch(
      payload: {
        request_text: request_text,
        order_type: "market",
        submitted_by: "demo@example.com"
      },
      subject: TradeRequest.create!(request_text: request_text, order_type: "market", submitted_by: "demo@example.com"),
      workflow: :trade_request
    )
  end
end
