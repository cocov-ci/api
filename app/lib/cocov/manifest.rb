# frozen_string_literal: true

module Cocov
  module Manifest
    class Error < StandardError; end
    class InvalidManifestError < Error; end

    VERSIONS = {
      "0.1.alpha" => V01Alpha
    }.freeze

    module_function

    def load(path)
      parse(File.read(path))
    end

    def parse(contents)
      data = YAML.load(contents)

      raise InvalidManifestError, "Invalid manifest: Root should be a mapping" unless data.is_a? Hash

      data = data.with_indifferent_access
      version = data[:version]

      raise InvalidManifestError, "Invalid manifest: Missing version field" if version.blank?

      raise InvalidManifestError, "Invalid manifest: Version must be a string" unless version.is_a? String

      raise InvalidManifestError, "Invalid manifest: Unsupported version #{version}" unless VERSIONS.key? version

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
