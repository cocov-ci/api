# frozen_string_literal: true

module Cocov
  class SchemaValidator
    class BaseValidator
      def validate(what, path)
        @path = path
        @what = what
        assert(what)
      end

      def assert(what)
        # :nocov:
        raise NotImplementedError, "#{self.class.name}#assert(what) is not implemented"
        # :nocov:
      end

      def clean(value)
        # :nocov:
        raise NotImplementedError, "#{self.class.name}#clean(value) is not implemented"
        # :nocov:
      end

      def join_path(other)
        @path + [other].flatten.compact
      end

      def run_validator(validator, value, path)
        validator.validate(value, join_path(path))
      end

      def err!(expectation) = custom_err!(nil, expectation, @what)

      def custom_err!(path, expectation, received)
        raise ValidationError.new(join_path(path), expectation, received)
      end
    end
  end
end
