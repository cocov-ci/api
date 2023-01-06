# frozen_string_literal: true

module Cocov
  module Manifest
    class V01Alpha
      Coverage = Struct.new(:path, :format, :min_percent, keyword_init: true)

      VALIDATOR = SchemaValidator.with do
        hash(
          version: string.reject_blank,
          coverage: opt(hash(
            path: opt(string.reject_blank),
            format: opt(string.reject_blank),
            min_percent: opt(integer)
          ).reject_extra_keys),
          checks: opt(array(hash(
            plugin: string.reject_blank,
            envs: opt(hash(alt(string, symbol) => string)),
            mounts: opt(array(hash(
              source: string.reject_blank,
              destination: string.reject_blank
            ).reject_extra_keys))
          ).reject_extra_keys))
        ).reject_extra_keys
      end

      class Check
        attr_reader :plugin

        def initialize(data)
          @plugin = data[:plugin]
        end
      end

      attr_reader :coverage, :checks

      def initialize(data)
        @data = data
        begin
          VALIDATOR.validate(data)
        rescue Cocov::SchemaValidator::ValidationError => e
          raise InvalidManifestError, e.message
        end

        @coverage = (Coverage.new(**@data[:coverage]) if @data.fetch(:coverage, nil))

        @checks = @data[:checks]&.map { Check.new(_1) } || []
      end
    end
  end
end
