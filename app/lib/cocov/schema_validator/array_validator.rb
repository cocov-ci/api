# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class ArrayValidator < BaseValidator
      def initialize(value)
        super()
        @value = value
      end

      def inspect = "array(#{@value.inspect})"

      def assert(what)
        err! Array unless what.is_a? Array

        what.each.with_index do |v, idx|
          run_validator(@value, v, idx)
        end
      end
    end
  end
end
