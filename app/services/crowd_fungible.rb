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

    def company_symbol_aliases
      config.company_symbol_aliases.to_h.transform_keys { |symbol| symbol.to_s.upcase }
            .transform_values { |aliases| Array(aliases).map { |alias_name| alias_name.to_s.downcase } }
    end

    def resolve_company_symbol(text)
      normalized_text = text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
      return if normalized_text.blank?

      company_symbol_aliases.each do |symbol, aliases|
        matched_alias = aliases.sort_by { |alias_name| -alias_name.length }.find do |alias_name|
          normalized_text.match?(/\b#{Regexp.escape(alias_name)}\b/)
        end
        return { symbol:, matched_alias: matched_alias } if matched_alias.present?
      end

      nil
    end

    def extract_company_reference(text)
      source = text.to_s.strip
      return if source.blank?

      patterns = [
        /\bshares?\s+of\s+([a-z][a-z0-9&.\- ]+)/i,
        /\b(?:into|in)\s+([a-z][a-z0-9&.\- ]+)/i
      ]

      patterns.each do |pattern|
        match = source.match(pattern)
        next unless match

        candidate = match[1].to_s.split(/\b(?:if|when|unless|and then|but)\b/i).first.to_s
        candidate = candidate.gsub(/[^a-z0-9&.\- ]+/i, " ").squish
        next if candidate.blank?

        return candidate
      end

      nil
    end
  end
end
