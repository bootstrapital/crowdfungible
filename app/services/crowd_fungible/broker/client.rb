# frozen_string_literal: true

module CrowdFungible
  module Broker
    class Client
      class << self
        def build(connection: nil)
          return FakeClient.new if CrowdFungible.broker_mode == "fake"

          AlpacaClient.new(connection: connection)
        end
      end
    end
  end
end
