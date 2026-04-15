# frozen_string_literal: true

module CrowdFungible
  module TradeRequest
    class ResolveCompanySymbolTool < Rubot::Tool
      description "Resolve commonly known allowlisted company names into supported ticker symbols."
      idempotent!

      input_schema do
        string :request_text, required: false
        hash :normalized_request do
          string :side, required: false
          string :symbol, required: false
          float :quantity, required: false
          float :notional_usd, required: false
          string :order_type, required: false
          float :confidence_score, required: false
          string :normalization_summary, required: false
          array :ambiguity_flags, of: :string, required: false
          string :requested_company_name, required: false
        end
      end

      output_schema do
        string :side, required: false
        string :symbol, required: false
        float :quantity, required: false
        float :notional_usd, required: false
        string :order_type, required: false
        float :confidence_score, required: false
        string :normalization_summary, required: false
        array :ambiguity_flags, of: :string, required: false
        string :resolved_from_company_alias, required: false
        string :requested_company_name, required: false
      end

      def call(request_text:, normalized_request:)
        request = normalized_request.deep_symbolize_keys
        return request if request[:symbol].present?

        resolution = CrowdFungible.resolve_company_symbol(request_text)
        if resolution
          ambiguity_flags = Array(request[:ambiguity_flags]) - ["missing_symbol"]

          return CrowdFungible::RequestParser.finalize(
            request.merge(
              symbol: resolution.fetch(:symbol),
              ambiguity_flags: ambiguity_flags,
              resolved_from_company_alias: resolution.fetch(:matched_alias)
            )
          )
        end

        requested_company_name = CrowdFungible.extract_company_reference(request_text)
        return request if requested_company_name.blank?

        ambiguity_flags = (Array(request[:ambiguity_flags]) - ["missing_symbol"]) | ["unsupported_company_name"]

        CrowdFungible::RequestParser.finalize(
          request.merge(
            requested_company_name: requested_company_name,
            ambiguity_flags: ambiguity_flags
          )
        )
      end
    end
  end
end
