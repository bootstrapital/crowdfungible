# frozen_string_literal: true

require "test_helper"

class TradeRequestWorkflowTest < ActiveSupport::TestCase
  test "clear small buy executes" do
    run = launch("Buy 2 shares of AAPL")

    assert_equal :completed, run.status
    assert_equal "executed", run.output[:final_disposition]
    assert_equal "execute", run.output.dig(:policy_result, :decision)
  end

  test "large request routes to approval" do
    run = launch("Buy $5000 of NVDA")

    assert_equal :waiting_for_approval, run.status
    assert_equal "require_approval", run.state.dig(:evaluate_trade_policy, :decision)
  end

  test "invalid symbol rejects" do
    run = launch("Buy 5 shares of ZZZZ")

    assert_equal :completed, run.status
    assert_equal "rejected", run.output[:final_disposition]
    assert_equal "reject", run.output.dig(:policy_result, :decision)
  end

  test "ambiguous request routes to approval" do
    run = launch("Put $500 into NVDA if cash is available")

    assert_equal :waiting_for_approval, run.status
    assert_equal "require_approval", run.state.dig(:evaluate_trade_policy, :decision)
  end

  test "approval resume leads to execution" do
    run = launch("Buy $5000 of NVDA")

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
