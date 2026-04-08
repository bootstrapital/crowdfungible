# frozen_string_literal: true

module CrowdFungible
  class RequestParser
    BUY_PATTERNS = /\b(buy|purchase|add|long)\b/i
    SELL_PATTERNS = /\b(sell|trim|exit|short)\b/i
    NOTIONAL_PATTERN = /\$(\d+(?:\.\d+)?)/i
    SHARES_PATTERN = /(\d+(?:\.\d+)?)\s+shares?/i
    SYMBOL_PATTERN = /\b([A-Z]{1,5})\b/

    class << self
      def normalize(input)
        source_text = input[:request_text].to_s.strip
        side = explicit_or_inferred_side(input[:side], source_text)
        symbol = explicit_or_inferred_symbol(input[:symbol], source_text)
        quantity = explicit_or_inferred_quantity(input[:quantity], source_text)
        notional_usd = explicit_or_inferred_notional(input[:notional_usd], source_text)
        order_type = input[:order_type].presence || "market"
        ambiguity_flags = build_ambiguity_flags(source_text, side:, symbol:, quantity:, notional_usd:)
        confidence_score = compute_confidence(side:, symbol:, quantity:, notional_usd:, ambiguity_flags:)

        {
          interpreted_action: side,
          side: side,
          symbol: symbol,
          quantity: quantity,
          notional_usd: notional_usd,
          order_type: order_type,
          confidence_score: confidence_score,
          ambiguity_flags: ambiguity_flags,
          normalization_summary: summary_for(side:, symbol:, quantity:, notional_usd:, order_type:, ambiguity_flags:)
        }
      end

      private

      def explicit_or_inferred_side(explicit_side, text)
        return explicit_side.to_s.downcase if explicit_side.present?
        return "buy" if text.match?(BUY_PATTERNS)
        return "sell" if text.match?(SELL_PATTERNS)

        nil
      end

      def explicit_or_inferred_symbol(explicit_symbol, text)
        return explicit_symbol.to_s.upcase if explicit_symbol.present?

        detected = text.scan(SYMBOL_PATTERN).flatten.map(&:upcase)
        detected.find { |candidate| CrowdFungible.symbol_allowlist.include?(candidate) } || detected.first
      end

      def explicit_or_inferred_quantity(explicit_quantity, text)
        return explicit_quantity.to_f if explicit_quantity.present?

        match = text.match(SHARES_PATTERN)
        match && match[1].to_f
      end

      def explicit_or_inferred_notional(explicit_notional, text)
        return explicit_notional.to_f if explicit_notional.present?

        match = text.match(NOTIONAL_PATTERN)
        match && match[1].to_f
      end

      def build_ambiguity_flags(text, side:, symbol:, quantity:, notional_usd:)
        flags = []
        flags << "missing_side" if side.blank?
        flags << "missing_symbol" if symbol.blank?
        flags << "missing_size" if quantity.blank? && notional_usd.blank?
        flags << "fractional_position_reference" if text.match?(/\bhalf\b/i) || text.match?(/\ball\b/i)
        flags << "conditional_language" if text.match?(/\bif\b/i)
        flags << "competing_size_inputs" if quantity.present? && notional_usd.present?
        flags
      end

      def compute_confidence(side:, symbol:, quantity:, notional_usd:, ambiguity_flags:)
        score = 0.2
        score += 0.25 if side.present?
        score += 0.25 if symbol.present?
        score += 0.2 if quantity.present? || notional_usd.present?
        score -= 0.1 * ambiguity_flags.size
        score.clamp(0.0, 0.99).round(2)
      end

      def summary_for(side:, symbol:, quantity:, notional_usd:, order_type:, ambiguity_flags:)
        parts = []
        parts << side&.capitalize || "Unclear action"
        parts << (quantity.present? ? "#{quantity} shares" : "$#{format("%.2f", notional_usd)}")
        parts << "of #{symbol}" if symbol.present?
        parts << "as a #{order_type} order"
        parts << "(#{ambiguity_flags.join(', ')})" if ambiguity_flags.any?
        parts.compact.join(" ")
      end
    end
  end
end
