# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class MissingKeyError < ValidationError
      attr_reader :path, :key_name

      def initialize(path, key_name)
        @path = path
        @key_name = key_name
        super(to_s)
      end

      def to_s
        "#{@path.join(".")} is missing a required key: #{@key_name}"
      end
    end
  end
end
