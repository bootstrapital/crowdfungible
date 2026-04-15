# frozen_string_literal: true

require "test_helper"

class AlpacaClientTest < ActiveSupport::TestCase
  test "account normalizes broker payload when trading base url already includes /v2" do
    Rails.application.config.x.crowd_fungible.alpaca_base_url = "https://paper-api.alpaca.markets/v2"

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
    Rails.application.config.x.crowd_fungible.alpaca_base_url = "https://paper-api.alpaca.markets/v2"

    client = CrowdFungible::Broker::AlpacaClient.new(connection: connection_for do |stub|
      stub.post("/v2/orders") do |env|
        payload = JSON.parse(env.body)

        assert_equal "AAPL", payload["symbol"]
        assert_equal "buy", payload["side"]
        assert_equal "market", payload["type"]
        assert_equal "day", payload["time_in_force"]
        assert_equal "2.0", payload["qty"]

        [200, { "Content-Type" => "application/json" }, JSON.generate(id: "ord_123", status: "accepted", symbol: "AAPL", side: "buy", qty: "2", type: "market", filled_avg_price: "191.22", submitted_at: "2026-04-04T15:00:00Z")]
      end
    end)

    result = client.place_order(order: { symbol: "AAPL", side: "buy", quantity: 2.0, order_type: "market" })

    assert_equal "ord_123", result[:order_id]
    assert_equal true, result[:paper]
    assert_equal 2.0, result[:quantity]
  end

  test "quote requests latest stock quote from market data api" do
    Rails.application.config.x.crowd_fungible.alpaca_market_data_url = "https://data.alpaca.markets"

    client = CrowdFungible::Broker::AlpacaClient.new(connection: connection_for(base_url: "https://data.alpaca.markets") do |stub|
      stub.get("/v2/stocks/AAPL/quotes/latest") do
        [200, { "Content-Type" => "application/json" }, JSON.generate(quote: { bp: 190.1, ap: 190.3 })]
      end
    end)

    result = client.quote(symbol: "aapl")

    assert_equal "AAPL", result[:symbol]
    assert_equal 190.1, result[:bid_price]
    assert_equal 190.3, result[:ask_price]
    assert_equal 190.2, result[:last_price]
  end

  test "non-paper trading endpoints are rejected for order placement" do
    Rails.application.config.x.crowd_fungible.alpaca_base_url = "https://api.alpaca.markets/v2"

    client = CrowdFungible::Broker::AlpacaClient.new

    error = assert_raises(CrowdFungible::BrokerError) do
      client.place_order(order: { symbol: "AAPL", side: "buy", quantity: 2.0, order_type: "market" })
    end

    assert_includes error.message, "restricted to Alpaca paper trading endpoints"
  end

  private

  def connection_for(base_url: "https://paper-api.alpaca.markets", &block)
    stubs = Faraday::Adapter::Test::Stubs.new(&block)

    Faraday.new(url: base_url) do |faraday|
      faraday.adapter :test, stubs
    end
  end
end
