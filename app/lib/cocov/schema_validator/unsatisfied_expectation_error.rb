# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class UnsatisfiedExpectationError < ValidationError
      attr_reader :path, :expected, :received

      def initialize(path, expected, received)
        @path = path
        @expected = expected
        @received = received
        super(to_s)
      end

      def to_s
        "Expected #{@path.join(".")} to match #{@expected.inspect}. " \
          "Assertion failed due to current object's value: #{@received.inspect}"
      end
    end
  end
end
