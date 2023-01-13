# frozen_string_literal: true

class WebhookProcessorService
  class RepositoryDeletedHandler < BaseHandler
    wants :repository, :deleted

    def handle
      repo = repository_for_event or return
      DestroyRepositoryJob.perform_later(repo.id)
    end
  end
end
