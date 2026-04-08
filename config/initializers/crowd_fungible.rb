Rails.application.config.x.crowd_fungible = ActiveSupport::OrderedOptions.new.tap do |config|
  config.broker_mode = ENV.fetch("CROWDFUNGIBLE_BROKER_MODE", Rails.env.production? ? "alpaca" : "fake")
  config.alpaca_base_url = ENV.fetch("ALPACA_PAPER_BASE_URL", "https://paper-api.alpaca.markets")
  config.alpaca_market_data_url = ENV.fetch("ALPACA_MARKET_DATA_URL", "https://data.alpaca.markets")
  config.alpaca_api_key = ENV["ALPACA_API_KEY"]
  config.alpaca_secret_key = ENV["ALPACA_SECRET_KEY"]
  config.auto_approval_notional_threshold = ENV.fetch("CROWDFUNGIBLE_AUTO_APPROVAL_NOTIONAL_THRESHOLD", "1000")
  config.concentration_threshold = ENV.fetch("CROWDFUNGIBLE_CONCENTRATION_THRESHOLD", "0.25")
  config.low_buying_power_threshold = ENV.fetch("CROWDFUNGIBLE_LOW_BUYING_POWER_THRESHOLD", "1000")
  config.symbol_allowlist = ENV.fetch("CROWDFUNGIBLE_SYMBOL_ALLOWLIST", "AAPL,AMZN,GOOGL,META,MSFT,NVDA,TSLA").split(",").map { |value| value.strip.upcase }.reject(&:blank?)
end
