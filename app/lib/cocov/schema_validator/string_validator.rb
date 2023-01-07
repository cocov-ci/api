# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class StringValidator < BaseValidator
      def inspect = "string"

      def reject_blank
        @reject_blank = true
        self
      end

      def assert(what)
        err! self unless what.is_a? String

        return unless @reject_blank && what.blank?

        raise StringValidationError.new(join_path, "not be blank")
      end

      def clean(value) = value.to_s
    end
  end
end
