ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    setup do
      Rails.application.config.x.crowd_fungible.broker_mode = "fake"
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
