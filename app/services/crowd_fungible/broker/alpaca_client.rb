# frozen_string_literal: true

module CrowdFungible
  module Broker
    class AlpacaClient
      TRADING_API_VERSION_PREFIX = "/v2".freeze

      def initialize(connection: nil)
        @connection = connection
      end

      def account
        response = request(:get, trading_url("/account"))
        body = response.body

        {
          account_id: body.fetch("id"),
          buying_power: body.fetch("buying_power").to_f,
          cash: body.fetch("cash").to_f,
          portfolio_value: body.fetch("portfolio_value").to_f,
          currency: body.fetch("currency"),
          status: body.fetch("status")
        }
      end

      def positions
        response = request(:get, trading_url("/positions"))

        Array(response.body).map do |position|
          {
            symbol: position.fetch("symbol"),
            quantity: position.fetch("qty").to_f,
            market_value: position.fetch("market_value").to_f,
            current_price: position.fetch("current_price").to_f,
            side: position.fetch("side")
          }
        end
      end

      def open_orders
        response = request(:get, trading_url("/orders"), params: { status: "open", direction: "desc" })

        Array(response.body).map do |order|
          {
            order_id: order.fetch("id"),
            symbol: order.fetch("symbol"),
            side: order.fetch("side"),
            quantity: order["qty"]&.to_f,
            notional_usd: order["notional"]&.to_f,
            order_type: order.fetch("type"),
            status: order.fetch("status")
          }
        end
      end

      def quote(symbol:)
        response = request(:get, market_data_url("/v2/stocks/#{symbol.upcase}/quotes/latest"))
        quote = response.body.fetch("quote")
        bid_price = quote.fetch("bp").to_f
        ask_price = quote.fetch("ap").to_f
        midpoint = ((bid_price + ask_price) / 2.0).round(4)

        {
          symbol: symbol.upcase,
          ask_price: ask_price,
          bid_price: bid_price,
          last_price: midpoint,
          source: "alpaca_latest_quote"
        }
      end

      def place_order(order:)
        ensure_paper_endpoint!

        payload = {
          symbol: order.fetch(:symbol).upcase,
          side: order.fetch(:side),
          type: order.fetch(:order_type),
          time_in_force: "day"
        }
        payload[:qty] = order[:quantity].to_s if order[:quantity].present?
        payload[:notional] = order[:notional_usd].to_s if order[:notional_usd].present?

        response = request(:post, trading_url("/orders"), json: payload)
        body = response.body

        {
          order_id: body.fetch("id"),
          broker_status: body.fetch("status"),
          symbol: body.fetch("symbol"),
          side: body.fetch("side"),
          quantity: body["qty"]&.to_f,
          notional_usd: body["notional"]&.to_f,
          order_type: body.fetch("type"),
          filled_avg_price: body["filled_avg_price"]&.to_f,
          submitted_at: body.fetch("submitted_at"),
          paper: true
        }
      end

      private

      attr_reader :connection

      def request(method, url, params: nil, json: nil)
        options = {
          params: params,
          headers: auth_headers,
          connection: connection
        }
        options[:json] = json if json.present?

        Rubot::HTTP.public_send(method, url, **options)
      rescue Rubot::HTTPError => e
        raise CrowdFungible::BrokerError, "Alpaca request failed: #{e.message}"
      end

      def auth_headers
        {
          "APCA-API-KEY-ID" => CrowdFungible.config.alpaca_api_key.to_s,
          "APCA-API-SECRET-KEY" => CrowdFungible.config.alpaca_secret_key.to_s
        }
      end

      def trading_url(path)
        join_api_url(CrowdFungible.config.alpaca_base_url, path, version_prefix: TRADING_API_VERSION_PREFIX)
      end

      def market_data_url(path)
        join_api_url(CrowdFungible.config.alpaca_market_data_url, path)
      end

      def join_api_url(base_url, path, version_prefix: nil)
        normalized_base = base_url.to_s.sub(%r{/\z}, "")
        normalized_path = "/#{path.to_s.sub(%r{\A/+}, "")}"

        if version_prefix && normalized_base.end_with?(version_prefix) && normalized_path.start_with?(version_prefix)
          normalized_path = normalized_path.delete_prefix(version_prefix)
        end

        "#{normalized_base}#{normalized_path}"
      end

      def ensure_paper_endpoint!
        trading_uri = URI.parse(CrowdFungible.config.alpaca_base_url.to_s)
        return if trading_uri.host&.include?("paper-api.alpaca.markets")

        raise CrowdFungible::BrokerError, "Order placement is restricted to Alpaca paper trading endpoints"
      rescue URI::InvalidURIError
        raise CrowdFungible::BrokerError, "Alpaca trading endpoint is invalid"
      end
    end
  end
end
