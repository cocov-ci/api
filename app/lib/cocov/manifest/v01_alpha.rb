# frozen_string_literal: true

module Cocov
  module Manifest
    class V01Alpha
      Coverage = Struct.new(:min_percent, keyword_init: true)
      Check = Struct.new(:plugin, :envs, :mounts, keyword_init: true)
      CheckMount = Struct.new(:source, :destination, keyword_init: true)
      ChecksDefaults = Struct.new(:envs, :mounts)
      Defaults = Struct.new(:checks)

      VALIDATOR = SchemaValidator.with do
        envs_schema = opt(hash(alt(string, symbol) => string))
        mounts_schema = opt(array(hash(
          source: string.reject_blank,
          destination: string.reject_blank
        ).reject_extra_keys))

        hash(
          version: string.reject_blank,
          coverage: opt(hash(
            min_percent: opt(integer)
          ).reject_extra_keys),
          exclude_paths: opt(array(string.reject_blank)),
          defaults: opt(hash(
            checks: opt(hash(
              envs: envs_schema,
              mounts: mounts_schema
            ).reject_extra_keys)
          ).reject_extra_keys),
          checks: opt(array(hash(
            plugin: string.reject_blank,
            envs: envs_schema,
            mounts: mounts_schema
          ).reject_extra_keys))
        ).reject_extra_keys
      end

      attr_reader :coverage, :checks, :exclude_paths, :defaults

      def prepare_defaults
        return unless @data.key? :defaults
        defs = @data[:defaults]
        Defaults.new.tap do |d|
          next unless defs.key? :checks
          checks = defs[:checks]
          d.checks = ChecksDefaults.new
          d.checks.envs = checks[:envs]
          d.checks.mounts = checks[:mounts]&.map { CheckMount.new(_1) }
          validate_mounts(d.checks.mounts, "defaults definition") if d.checks.mounts
        end
      end

      def validate_mounts(mounts, source)
        known_targets = []
        mounts.each do |m|
          if known_targets.include? m.destination
            raise InvalidManifestError, "Duplicated mount destination `#{m.destination}' in " \
                                        "#{source}"
          end
          known_targets << m.destination

          next if /^secrets:/.match?(m.source)

          raise InvalidManifestError, "Invalid mount source `#{m.source}' in #{source}:" \
                                      "Only secrets are mountable."
        end
      end

      def merge_default_mounts(into)
        return if @defaults&.checks&.mounts.blank?
        into.mounts ||= []

        @defaults.checks.mounts.each do |def_mount|
          next if into.mounts.any? { |m| m.destination == def_mount.destination }
          into.mounts << def_mount
        end
      end

      def initialize(data)
        begin
          VALIDATOR.validate(data)
        rescue Cocov::SchemaValidator::ValidationError => e
          raise InvalidManifestError, e.message
        end

        @data = data

        @defaults = prepare_defaults

        @coverage = (Coverage.new(**@data[:coverage]) if @data[:coverage])

        @checks = @data.fetch(:checks, []).map do |check|
          check[:mounts] = check[:mounts]&.map { CheckMount.new(_1) }

          if @defaults&.checks&.envs
            check[:envs] ||= check.fetch(:envs, {})
              .merge(@defaults.checks.envs)
          end
          Check.new(**check)
        end

        @checks.each do |c|
          validate_mounts(c.mounts, "plugin `#{c.plugin}'") unless c.mounts.blank?
          merge_default_mounts(c)
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
