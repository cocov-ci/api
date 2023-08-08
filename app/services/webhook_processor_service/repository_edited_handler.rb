# frozen_string_literal: true

class WebhookProcessorService
  class RepositoryEditedHandler < BaseHandler
    wants :repository, :edited

    WANTED_CHANGES = %i[description default_branch].freeze

    def validate
      changes = event[:changes].keys.map(&:to_sym)
      WANTED_CHANGES.intersect?(changes)
    end

    def handle
      repo = repository_for_event or return
      repo.description = event.dig(:repository, :description)
      repo.default_branch = event.dig(:repository, :default_branch)
      repo.save!
    end
  end
end
