# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class UnsatisfiedArrayLengthError < ValidationError
      attr_reader :path, :mode, :expected, :received

      def initialize(path, mode, expected, received)
        @path = path
        @expected = expected
        @received = received
        @mode = mode
        super(to_s)
      end

      def to_s
        "Expected list at #{@path.join(".")} to have #{@mode} #{@expected} items. " \
          "Assertion failed due to current list's length: #{@received}"
      end
    end
  end
end
