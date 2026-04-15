# frozen_string_literal: true

require "test_helper"

class TradeRequestsFlowTest < ActionDispatch::IntegrationTest
  test "submission page renders" do
    get new_trade_request_path

    assert_response :success
    assert_match "Paper Trading Only", response.body
  end

  test "request submission launches a rubot run and renders result" do
    post trade_requests_path, params: {
      trade_request: {
        request_text: "Buy 2 shares of AAPL",
        order_type: "market",
        submitted_by: "demo@example.com"
      }
    }

    trade_request = TradeRequest.order(:created_at).last

    assert_redirected_to trade_request_path(trade_request)
    assert trade_request.rubot_run_id.present?

    follow_redirect!
    assert_response :success
    assert_match "Trade Outcome", response.body
    assert_match "Executed", response.body
  end

  test "company name request resolves through the workflow" do
    post trade_requests_path, params: {
      trade_request: {
        request_text: "Buy 2 shares of Apple",
        order_type: "market",
        submitted_by: "demo@example.com"
      }
    }

    trade_request = TradeRequest.order(:created_at).last

    assert_redirected_to trade_request_path(trade_request)
    assert trade_request.rubot_run_id.present?

    follow_redirect!
    assert_response :success
    assert_match "AAPL", response.body
    assert_match "Executed", response.body
  end

  test "result page renders queued approval state" do
    post trade_requests_path, params: {
      trade_request: {
        request_text: "Put $25000 into NVDA",
        order_type: "market",
        submitted_by: "demo@example.com"
      }
    }

    trade_request = TradeRequest.order(:created_at).last
    follow_redirect!

    assert_equal "queued_for_approval", trade_request.reload.status
    assert_match "Open Approval Inbox", response.body
  end
end
