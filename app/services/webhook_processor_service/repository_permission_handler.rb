# frozen_string_literal: true

class WebhookProcessorService
  class RepositoryPermissionHandler < BaseHandler
    wants :public
    wants :repository
    wants :member
    wants :team_add

    def validate
      event[:action] != "deleted"
    end

    def handle
      repo = repository_for_event or return
      UpdateRepoPermissionsJob.perform_later(repo.id)
    end
  end
end
