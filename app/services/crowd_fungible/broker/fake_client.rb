# frozen_string_literal: true

module CrowdFungible
  module Broker
    class FakeClient
      PRICE_BOOK = {
        "AAPL" => 192.15,
        "AMZN" => 178.22,
        "GOOGL" => 154.44,
        "META" => 503.33,
        "MSFT" => 428.76,
        "NVDA" => 118.40,
        "TSLA" => 171.28,
        "V" => 273.61,
        "LNG" => 166.84,
        "MU" => 126.57
      }.freeze

      def account
        {
          account_id: "fake-paper-account",
          buying_power: 20_000.0,
          cash: 12_500.0,
          portfolio_value: 25_000.0,
          currency: "USD",
          status: "ACTIVE"
        }
      end

      def positions
        [
          normalize_position("AAPL", qty: 10.0),
          normalize_position("TSLA", qty: 6.0)
        ]
      end

      def open_orders
        []
      end

      def quote(symbol:)
        price = PRICE_BOOK.fetch(symbol.upcase) { raise CrowdFungible::BrokerError, "No paper quote available for #{symbol}" }

        {
          symbol: symbol.upcase,
          ask_price: price + 0.18,
          bid_price: price - 0.18,
          last_price: price,
          source: "fake"
        }
      end

      def place_order(order:)
        {
          order_id: "fake-#{SecureRandom.hex(6)}",
          broker_status: "accepted",
          symbol: order.fetch(:symbol),
          side: order.fetch(:side),
          quantity: order[:quantity],
          notional_usd: order[:notional_usd],
          order_type: order.fetch(:order_type),
          filled_avg_price: quote(symbol: order.fetch(:symbol)).fetch(:last_price),
          submitted_at: Time.current.iso8601,
          paper: true
        }
      end

      private

      def normalize_position(symbol, qty:)
        quote = quote(symbol:)
        market_value = qty * quote.fetch(:last_price)

        {
          symbol: symbol,
          quantity: qty,
          market_value: market_value.round(2),
          current_price: quote.fetch(:last_price),
          side: "long"
        }
      end
    end
  end
end
