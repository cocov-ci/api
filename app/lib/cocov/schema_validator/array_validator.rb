# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class ArrayValidator < BaseValidator
      def initialize(value)
        super()
        @value = value
        @min_length = nil
        @max_length = nil
      end

      def min_length(val)
        @min_length = val
        self
      end

      def max_length(val)
        @max_length = val
        self
      end

      def inspect = "array(#{@value.inspect})"

      def assert(what)
        err! Array unless what.is_a? Array

        if @min_length.present? && what.length < @min_length
          raise UnsatisfiedArrayLength.new(join_path(nil), "at least", @min_length, what.length)
        end

        if @max_length.present? && what.length > @max_length
          raise UnsatisfiedArrayLength.new(join_path(nil), "at most", @max_length, what.length)
        end

        what.each.with_index do |v, idx|
          run_validator(@value, v, idx)
        end
      end
    end
  end
end
