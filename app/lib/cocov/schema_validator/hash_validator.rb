# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class HashValidator < BaseValidator
      def initialize(value)
        super()
        @value = value
        @static_keys = value.keys.reject { _1.is_a? BaseValidator }
        @validator_keys = value.keys.filter { _1.is_a? BaseValidator }
        @reject_extra_keys = false
      end

      def reject_extra_keys
        @reject_extra_keys = true
        self
      end

      def inspect
        result = []
        @value.each do |k, v|
          result << k.inspect.to_s
          result << "=>"
          result << "#{v.inspect},"
        end
        result[result.length - 1] = result.last[...-1] if result.length.positive?
        "hash(#{result.join(" ")})"
      end

      def assert_key(key)
        if key.is_a?(String) || key.is_a?(Symbol)
          k = key.to_s
          return k if @static_keys.include? k

          k = key.to_sym
          return k if @static_keys.include? k
        end

        return key if @static_keys.include?(key)

        @validator_keys.each do |validator|
          validator.validate(key, [])
          return validator
        rescue ValidationError
          # Do nothing
        end

        # If opted-in, emit an error indicating we have an extra key that
        # shouldn't be there.
        unexpected_key! key if @reject_extra_keys

        # At this point, all checks failed, or the key shouldn't be there.
        # Leave it there as it is, as the clean procedure will get rid of it.
        nil
      end

      def assert_value(key, value, using)
        run_validator(using, value, key)
      end

      def assert(what)
        err! Hash unless what.is_a? Hash

        what.each do |k, v|
          value_k = assert_key(k)
          next if value_k.nil?

          assert_value(k, v, @value[value_k])
        end

        @static_keys.each do |k|
          next if @value[k].is_a? OptValidator # Optional is optional.

          exists = if k.is_a?(String) || k.is_a?(Symbol)
            what.key?(k.to_s) || what.key?(k.to_sym)
          else
            what.key?(k)
          end

          next if exists

          raise MissingKeyError.new(join_path, k)
        end
      end

      def clean(value)
        {}.tap do |result|
          value.each do |k, v|
            handler_key = assert_key(k)
            next if handler_key.nil?

            result[k] = @value[handler_key].clean(v)
          end
        end.with_indifferent_access
      end
    end
  end
end
