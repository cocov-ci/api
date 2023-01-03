# frozen_string_literal: true

module Cocov
  class SchemaValidator
    def self.with(&)
      new.tap do |inst|
        inst.instance_variable_set(:@validator, inst.instance_exec(&))
      end
    end

    def hash(val) = HashValidator.new(val)
    def array(val) = ArrayValidator.new(val)
    def alt(*vals) = AltValidator.new(vals)
    def string = StringValidator.new
    def symbol = SymbolValidator.new
    def nil_value = NilValidator.new
    def integer = IntegerValidator.new
    def opt(val) = OptValidator.new(val)

    def initialize
      @validator = nil
    end

    def normalize_params(params)
      case params
      when ActionController::Parameters, Hash
        {}.tap do |h|
          params.each { |k, v| h[normalize_params(k)] = normalize_params(v) }
        end
      when Array
        params.map { normalize_params(_1) }
      else
        params
      end
    end

    def validate(against)
      vals = normalize_params(against).tap do |params|
        @validator.validate(params, [])
      end

      @validator.clean(vals)
    end

    def inspect
      @validator.inspect
    end
  end
end
