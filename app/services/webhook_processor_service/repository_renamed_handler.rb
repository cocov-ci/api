# frozen_string_literal: true

class WebhookProcessorService
  class RepositoryRenamedHandler < BaseHandler
    wants :repository, :renamed

    def handle
      repo = repository_for_event or return
      repo.name = event.dig(:repository, :name)
      repo.save!
    end
  end
end
