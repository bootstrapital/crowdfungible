# frozen_string_literal: true

require "json"
require "open3"
require "timeout"

module CrowdFungible
  module RubotProviders
    class GeminiCli < Rubot::Providers::Base
      DEFAULT_TIMEOUT_SECONDS = 90
      DEFAULT_MODEL = "gemini-3-flash-preview"

      def complete(messages:, tools: [], output_schema: nil, model: nil, **_options)
        raise Rubot::ExecutionError, "Gemini CLI provider does not support tool calls" if tools.any?

        model ||= DEFAULT_MODEL
        prompt = build_prompt(messages, output_schema)

        # Gemini CLI reads from stdin if - is used.
        command = [
          "gemini",
          "--model", model,
          "--output-format", "json",
          "-"
        ]

        stdout, stderr, status = run_gemini(command, prompt)
        raise Rubot::ExecutionError, gemini_failure_message(status:, stdout:, stderr:) unless status.success?

        parsed_response = JSON.parse(stdout, symbolize_names: true)
        content = parsed_response[:response].to_s
        
        output = if output_schema
                   begin
                     # Try to parse the content as JSON if an output schema is expected
                     # Gemini might include markdown blocks or other text, so we might need a more robust extraction
                     # but for now we assume it follows instructions and returns valid JSON.
                     json_content = extract_json(content)
                     parsed_output = JSON.parse(json_content, symbolize_names: true)
                     output_schema.validate!(parsed_output)
                     parsed_output
                   rescue JSON::ParserError => e
                     raise Rubot::ValidationError, "Gemini CLI did not return valid JSON for the schema: #{e.message}\nContent: #{content}"
                   end
                 else
                   content
                 end

        Rubot::Providers::Result.new(
          provider: "gemini_cli",
          model: model,
          content: content,
          output: output,
          tool_calls: [],
          usage: extract_usage(parsed_response, model),
          finish_reason: "stop",
          raw: { stdout: stdout, stderr: stderr }
        )
      rescue Timeout::Error
        raise Rubot::RetryableError.new("Gemini CLI timed out while normalizing the request", category: :provider_retryable)
      rescue JSON::ParserError => e
        raise Rubot::ValidationError, "Gemini CLI returned invalid JSON structure: #{e.message}"
      end

      private

      def extract_usage(parsed_response, model)
        # Extract token usage from the complex stats structure
        stats = parsed_response[:stats]
        return {} unless stats

        model_stats = stats.dig(:models, model.to_sym) || stats.dig(:models, model.to_s)
        return {} unless model_stats

        tokens = model_stats[:tokens] || {}
        {
          input_tokens: tokens[:input],
          output_tokens: tokens[:candidates],
          total_tokens: tokens[:total]
        }
      end

      def build_prompt(messages, output_schema)
        prompt = Array(messages).map do |message|
          role = message[:role].to_s.upcase
          content = message[:content].to_s
          "#{role}:\n#{content}"
        end.join("\n\n")

        if output_schema
          prompt += "\n\nIMPORTANT: You MUST respond ONLY with a JSON object that strictly follows this JSON schema:\n"
          prompt += JSON.pretty_generate(output_schema.to_json_schema)
          prompt += "\n\nDo not include any other text, markdown blocks, or explanations. Just the JSON object."
        end

        prompt
      end

      def extract_json(content)
        # Basic extraction in case the model wraps it in markdown blocks
        if content =~ /```json\s*(.*?)\s*```/m
          $1
        elsif content =~ /```\s*(.*?)\s*```/m
          $1
        else
          content
        end
      end

      def run_gemini(command, prompt)
        Timeout.timeout(timeout_seconds) do
          Open3.capture3(*command, stdin_data: prompt, chdir: Rails.root.to_s)
        end
      end

      def timeout_seconds
        ENV.fetch("CROWD_FUNGIBLE_GEMINI_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS).to_i
      end

      def gemini_failure_message(status:, stdout:, stderr:)
        details = [stderr.presence, stdout.presence].compact.join("\n").strip
        details = "No output captured from gemini." if details.blank?
        "Gemini CLI failed with exit #{status.exitstatus}: #{details}"
      end
    end
  end
end
