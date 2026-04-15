ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class CrowdFungibleTestProvider
  def complete(messages:, tools:, output_schema:, model:)
    payload = JSON.parse(Array(messages).last.fetch(:content), symbolize_names: true)
    input = payload.fetch(:input)

    output =
      case input[:task]
      when "normalize"
        { normalized_request: CrowdFungible::RequestParser.normalize(input) }
      else
        raise "Unsupported test provider task: #{input[:task].inspect}"
      end

    Rubot::Providers::Result.new(
      provider: "test",
      model: model,
      content: "",
      output: output,
      tool_calls: [],
      usage: {},
      finish_reason: "stop"
    )
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    setup do
      Rails.application.config.x.crowd_fungible.broker_mode = "fake"
      Rubot.configure do |config|
        config.provider = CrowdFungibleTestProvider.new
      end
    end

    teardown do
      Rubot::ApprovalRecord.delete_all if defined?(Rubot::ApprovalRecord)
      Rubot::ToolCallRecord.delete_all if defined?(Rubot::ToolCallRecord)
      Rubot::EventRecord.delete_all if defined?(Rubot::EventRecord)
      Rubot::RunRecord.delete_all if defined?(Rubot::RunRecord)
      TradeRequest.delete_all if defined?(TradeRequest)
    end
  end
end
