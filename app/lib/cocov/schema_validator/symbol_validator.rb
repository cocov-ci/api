# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class SymbolValidator < BaseValidator
      def inspect = "symbol"

      def assert(what)
        err! self unless what.is_a? Symbol
      end
    end
  end
end
