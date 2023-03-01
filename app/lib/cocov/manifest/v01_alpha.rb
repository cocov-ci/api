# frozen_string_literal: true

module Cocov
  module Manifest
    class V01Alpha
      Coverage = Struct.new(:min_percent, keyword_init: true)
      Check = Struct.new(:plugin, :envs, :mounts, keyword_init: true)
      CheckMount = Struct.new(:source, :destination, keyword_init: true)

      VALIDATOR = SchemaValidator.with do
        hash(
          version: string.reject_blank,
          coverage: opt(hash(
            min_percent: opt(integer)
          ).reject_extra_keys),
          exclude_paths: opt(array(string.reject_blank)),
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

      attr_reader :coverage, :checks, :exclude_paths

      def initialize(data)
        begin
          VALIDATOR.validate(data)
        rescue Cocov::SchemaValidator::ValidationError => e
          raise InvalidManifestError, e.message
        end

        @data = data

        @coverage = (Coverage.new(**@data[:coverage]) if @data.fetch(:coverage, nil))

        @checks = @data.fetch(:checks, []).map do |check|
          check[:mounts] = check[:mounts]&.map { CheckMount.new(_1) }
          Check.new(**check)
        end

        @checks.each do |c|
          next if c.mounts.blank?

          c.mounts.each do |m|
            next if /^secrets:/.match?(m.source)

            raise InvalidManifestError, "Invalid mount source `#{m.source} for " \
                                        "check #{c.plugin}: Only secrets are mountable."
          end
        end

        @exclude_paths = data[:exclude_paths]&.map do |path|
          next path unless path.end_with? "/"

          "#{path}*"
        end || []
      end

      def path_excluded?(path)
        @exclude_paths.any? do |pattern|
          File.fnmatch?(pattern, path, File::FNM_EXTGLOB | File::FNM_PATHNAME)
        end
      end
    end
  end
end
