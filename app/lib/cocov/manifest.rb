# frozen_string_literal: true

module Cocov
  module Manifest
    class Error < StandardError; end

    class InvalidManifestError < Error
      attr_reader :code

      def initialize(code, message)
        super(message)
        @code = code
      end
    end

    VERSIONS = {
      "0.1.alpha" => V01Alpha
    }.freeze

    module_function

    def load(path)
      parse(File.read(path))
    end

    def parse(contents)
      data = YAML.load(contents)

      unless data.is_a? Hash
        raise InvalidManifestError.new(
          :manifest_root_must_be_mapping,
          "Invalid manifest: Root should be a mapping"
        )
      end

      data = data.with_indifferent_access
      version = data[:version]

      if version.blank?
        raise InvalidManifestError.new(
          :manifest_missing_version,
          "Invalid manifest: Missing version field"
        )
      end

      unless version.is_a? String
        raise InvalidManifestError.new(
          :manifest_version_type_mismatch,
          "Invalid manifest: Version must be a string"
        )
      end

      unless VERSIONS.key? version
        raise InvalidManifestError.new(
          :manifest_version_unsupported,
          "Invalid manifest: Unsupported version #{version}"
        )
      end

      VERSIONS[version].new(data)
    end

    def cleanup_plugin_name(name)
      components = name.split("/")
      image_name = components.pop.split(":").first
      components = components.grep(/\A[a-z0-9]+\z/)
      [components.last, image_name].compact.join("/")
    end
  end
end
