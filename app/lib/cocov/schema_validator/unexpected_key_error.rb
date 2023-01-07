# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class UnexpectedKeyError < ValidationError
      attr_reader :path, :key_name

      def initialize(path, key_name)
        @path = path
        @key_name = key_name
        super(to_s)
      end

      def to_s
        "Unexpected extra key `#{@key_name}' on `#{@path.join(".")}'"
      end
    end
  end
end
