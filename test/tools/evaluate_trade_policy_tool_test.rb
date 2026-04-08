# frozen_string_literal: true

require "test_helper"

class EvaluateTradePolicyToolTest < ActiveSupport::TestCase
  test "small clear market order auto approves" do
    result = tool.call(
      normalized_request: normalized_request(symbol: "AAPL", quantity: 2.0, ambiguity_flags: []),
      account: { buying_power: 20_000.0 },
      positions: [],
      open_orders: [],
      quote: { available: true },
      impact: { impact_ready: true, estimated_notional_usd: 384.0, buying_power_after: 19_616.0, post_trade_concentration_pct: 0.09 }
    )

    assert_equal "execute", result[:decision]
    assert result[:auto_approvable]
  end

  test "oversized order requires approval" do
    result = tool.call(
      normalized_request: normalized_request(symbol: "NVDA", notional_usd: 5_000.0, ambiguity_flags: []),
      account: { buying_power: 20_000.0 },
      positions: [],
      open_orders: [],
      quote: { available: true },
      impact: { impact_ready: true, estimated_notional_usd: 5_000.0, buying_power_after: 15_000.0, post_trade_concentration_pct: 0.20 }
    )

    assert_equal "require_approval", result[:decision]
    assert_includes result[:flags], "large_notional"
  end

  test "invalid symbol rejects" do
    result = tool.call(
      normalized_request: normalized_request(symbol: "ZZZZ", quantity: 1.0, ambiguity_flags: []),
      account: { buying_power: 20_000.0 },
      positions: [],
      open_orders: [],
      quote: { available: false, reason: "Symbol is outside the demo allowlist." },
      impact: { impact_ready: false }
    )

    assert_equal "reject", result[:decision]
    assert result[:hard_rejection]
  end

  test "tight buying power escalates" do
    result = tool.call(
      normalized_request: normalized_request(symbol: "MSFT", notional_usd: 900.0, ambiguity_flags: []),
      account: { buying_power: 1_500.0 },
      positions: [],
      open_orders: [],
      quote: { available: true },
      impact: { impact_ready: true, estimated_notional_usd: 900.0, buying_power_after: 600.0, post_trade_concentration_pct: 0.10 }
    )

    assert_equal "require_approval", result[:decision]
    assert_includes result[:flags], "low_buying_power"
  end

  test "open order conflict escalates" do
    result = tool.call(
      normalized_request: normalized_request(symbol: "TSLA", quantity: 1.0, ambiguity_flags: []),
      account: { buying_power: 20_000.0 },
      positions: [],
      open_orders: [{ symbol: "TSLA", side: "buy", order_type: "market", status: "new" }],
      quote: { available: true },
      impact: { impact_ready: true, estimated_notional_usd: 171.0, buying_power_after: 19_829.0, post_trade_concentration_pct: 0.07 }
    )

    assert_equal "require_approval", result[:decision]
    assert_includes result[:flags], "open_order_conflict"
  end

  private

  def tool
    CrowdFungible::TradeRequest::EvaluateTradePolicyTool.new
  end

  def normalized_request(symbol:, quantity: nil, notional_usd: nil, ambiguity_flags:)
    {
      side: "buy",
      symbol: symbol,
      quantity: quantity,
      notional_usd: notional_usd,
      order_type: "market",
      ambiguity_flags: ambiguity_flags
    }
  end
end
