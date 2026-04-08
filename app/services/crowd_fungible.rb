# frozen_string_literal: true

module CrowdFungible
  class Error < StandardError; end
  class BrokerError < Error; end
  class PolicyError < Error; end

  class << self
    def config
      Rails.application.config.x.crowd_fungible
    end

    def broker_mode
      config.broker_mode.to_s
    end

    def auto_approval_notional_threshold
      config.auto_approval_notional_threshold.to_f
    end

    def concentration_threshold
      config.concentration_threshold.to_f
    end

    def low_buying_power_threshold
      config.low_buying_power_threshold.to_f
    end

    def symbol_allowlist
      Array(config.symbol_allowlist).map(&:to_s).map(&:upcase)
    end
  end
end
