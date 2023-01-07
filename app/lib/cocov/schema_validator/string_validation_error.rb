# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class StringValidationError < ValidationError
      attr_reader :path, :why

      def initialize(path, why)
        @path = path
        @why = why
        super(to_s)
      end

      def to_s
        "Expected #{@path.join(".")} to #{why}"
      end
    end
  end
end
