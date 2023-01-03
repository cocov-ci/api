# frozen_string_literal: true

module Cocov
  class Errors
    class StopError < StandardError
      attr_reader :path, :args

      def initialize(path, args)
        super()
        @path = path
        @args = args
      end
    end

    def self.instance
      @instance ||= Errors.new
    end

    def initialize
      @errors = YAML.load_file(Rails.root.join("config/errors.yml"))
        .with_indifferent_access
        .freeze
      @generic = {
        status: :internal_server_error,
        message: "An error prevented the operation from completing. Please try again."
      }.with_indifferent_access.freeze
    end

    def [](*args)
      @errors[:errors].dig(*args) || @generic
    end
  end
end
