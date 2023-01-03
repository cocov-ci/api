# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class OptValidator < BaseValidator
      def initialize(value)
        super()
        @value = value
      end

      def assert(what)
        return if what.nil?
        return run_validator(@value, what, nil) if @value.is_a? BaseValidator

        err! @value if what != @value
      end

      def clean(value) = value

      def inspect = "#{@value.inspect}?"
    end
  end
end
