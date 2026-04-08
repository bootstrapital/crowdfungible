# frozen_string_literal: true

require "test_helper"

class AlpacaClientTest < ActiveSupport::TestCase
  test "account normalizes broker payload" do
    client = CrowdFungible::Broker::AlpacaClient.new(connection: connection_for do |stub|
      stub.get("/v2/account") do
        [200, { "Content-Type" => "application/json" }, JSON.generate(id: "acct_123", buying_power: "10000", cash: "7000", portfolio_value: "12000", currency: "USD", status: "ACTIVE")]
      end
    end)

    result = client.account

    assert_equal "acct_123", result[:account_id]
    assert_equal 10_000.0, result[:buying_power]
  end

  test "place order normalizes paper-trading order response" do
    Rails.application.config.x.crowd_fungible.alpaca_base_url = "https://paper-api.alpaca.markets"

    client = CrowdFungible::Broker::AlpacaClient.new(connection: connection_for do |stub|
      stub.post("/v2/orders") do
        [200, { "Content-Type" => "application/json" }, JSON.generate(id: "ord_123", status: "accepted", symbol: "AAPL", side: "buy", qty: "2", type: "market", filled_avg_price: "191.22", submitted_at: "2026-04-04T15:00:00Z")]
      end
    end)

    result = client.place_order(order: { symbol: "AAPL", side: "buy", quantity: 2.0, order_type: "market" })

    assert_equal "ord_123", result[:order_id]
    assert_equal true, result[:paper]
    assert_equal 2.0, result[:quantity]
  end

  private

  def connection_for(&block)
    stubs = Faraday::Adapter::Test::Stubs.new(&block)

    Faraday.new(url: "https://paper-api.alpaca.markets") do |faraday|
      faraday.adapter :test, stubs
    end
  end
end
