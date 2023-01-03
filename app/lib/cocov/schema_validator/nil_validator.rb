# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class NilValidator < BaseValidator
      def inspect = "nil"

      def assert(what)
        return if what.nil?

        err! nil
      end
    end
  end
end
