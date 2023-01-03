# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class AltValidator < BaseValidator
      def initialize(opts)
        super()
        @opts = opts
      end

      def assert(what)
        ok = @opts.any? do |other|
          if other.is_a? BaseValidator
            run_validator(other, what, nil)
            next true
          end

          other == what
        rescue ValidationError
          false
        end

        err! self unless ok
      end

      def inspect
        result = []
        @opts.each { |opt| result << "#{opt.inspect}," }
        result[result.length - 1] = result.last[...-1] if result.length.positive?
        "alt(#{result.join(" ")})"
      end
    end
  end
end
