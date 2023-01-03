# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class StringValidator < BaseValidator
      def inspect = "string"

      def assert(what)
        err! self unless what.is_a? String
      end

      def clean(value) = value.to_s
    end
  end
end
