policy_config = Rails.application.config_for(:crowd_fungible_policy)

Rails.application.config.x.crowd_fungible = ActiveSupport::OrderedOptions.new.tap do |config|
  config.broker_mode = ENV.fetch("CROWDFUNGIBLE_BROKER_MODE", (Rails.env.production? || ENV["ALPACA_API_KEY"].present?) ? "alpaca" : "fake")
  config.alpaca_base_url = ENV.fetch("ALPACA_PAPER_BASE_URL", "https://paper-api.alpaca.markets/v2")
  config.alpaca_market_data_url = ENV.fetch("ALPACA_MARKET_DATA_URL", "https://data.alpaca.markets")
  config.alpaca_api_key = ENV["ALPACA_API_KEY"]
  config.alpaca_secret_key = ENV["ALPACA_SECRET_KEY"]
  config.auto_approval_notional_threshold =
    ENV.fetch("CROWDFUNGIBLE_AUTO_APPROVAL_NOTIONAL_THRESHOLD", policy_config.fetch(:auto_approval_notional_threshold).to_s)
  config.concentration_threshold =
    ENV.fetch("CROWDFUNGIBLE_CONCENTRATION_THRESHOLD", policy_config.fetch(:concentration_threshold).to_s)
  config.low_buying_power_threshold =
    ENV.fetch("CROWDFUNGIBLE_LOW_BUYING_POWER_THRESHOLD", policy_config.fetch(:low_buying_power_threshold).to_s)
  config.symbol_allowlist =
    ENV.fetch("CROWDFUNGIBLE_SYMBOL_ALLOWLIST", Array(policy_config.fetch(:symbol_allowlist)).join(","))
       .split(",")
       .map { |value| value.strip.upcase }
       .reject(&:blank?)
  config.company_symbol_aliases =
    policy_config.fetch(:company_symbol_aliases, {}).to_h.transform_keys(&:to_s).transform_values do |aliases|
      Array(aliases).map { |value| value.to_s.strip.downcase }.reject(&:blank?)
    end
end
