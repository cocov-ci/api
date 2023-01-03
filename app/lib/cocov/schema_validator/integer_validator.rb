# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class IntegerValidator < BaseValidator
      def inspect = "integer"

      def assert(what)
        err! Integer unless what.is_a? Integer
      end
    end
  end
end
