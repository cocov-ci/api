# frozen_string_literal: true

module Cocov
  class GitHubStatuses
    def self.instance
      @instance ||= GitHubStatuses.new
    end

    def initialize
      @errors = YAML.load_file(Rails.root.join("config/checks_statuses.yml"))
        .with_indifferent_access
        .freeze
    end

    def get(name, **args)
      return "An unknown error occurred" unless @errors.key? name

      @errors[name] % args
    end
  end
end
