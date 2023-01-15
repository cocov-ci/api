# frozen_string_literal: true

module Cocov
  class Redis
    class JsonEncoder
      class << self
        def encode(data) = data.to_json

        def decode(data) = JSON.parse(data, symbolize_names: true)
      end
    end
  end
end
