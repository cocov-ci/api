# frozen_string_literal: true

module Cocov
  module Manifest
    class V01Alpha
      Coverage = Struct.new(:path, :format, :min_percent, keyword_init: true)

      class Check
        attr_reader :plugin

        def initialize(data)
          @plugin = data[:plugin]
        end
      end

      def validate_type(*path, type:)
        val = @data.dig(*path)

        can_empty = type.is_a?(Array) && type.include?(NilClass)
        raise InvalidManifestError, "#{path.join(".")} should not be empty" if val.nil? && !can_empty

        if (type.is_a?(Array) && type.any? { val.is_a? _1 }) ||
           ((type.is_a?(Class) || type.is_a?(Module)) && val.is_a?(type))
          return
        end

        expected = type
        if type.is_a? Array
          type = type.map { _1 == NilClass ? nil : _1 }.map(&:inspect)
          expected = if type.length == 1
                       type.first
                     else
                       last = type.pop
                       "one of #{type.join(", ")} or #{last}"
                     end
        end
        raise InvalidManifestError, "#{path.join(".")}: Expected #{expected}, but found #{val.class}"
      end

      def validate_coverage!
        validate_type(:coverage, :path, type: String)
        validate_type(:coverage, :format, type: String)
        validate_type(:coverage, :min_percent, type: [Integer, NilClass])
      end

      def validate_checks!
        validate_type(:checks, type: Array)
        @data[:checks].each_index do |idx|
          validate_type(:checks, idx, :plugin, type: String)
        end
      end

      attr_reader :coverage, :checks

      def initialize(data)
        @data = data
        if @data.key? :coverage
          validate_coverage!
          @coverage = Coverage.new(**@data[:coverage])
        end

        @checks = []
        return unless @data.key? :checks

        validate_checks!
        @checks = @data[:checks].map { Check.new(_1) }
      end
    end
  end
end
