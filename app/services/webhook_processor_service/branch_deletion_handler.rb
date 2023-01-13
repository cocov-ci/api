# frozen_string_literal: true

class WebhookProcessorService
  class BranchDeletionHandler < BaseHandler
    wants :delete

    def validate
      event[:ref_type] == "branch"
    end

    def handle
      repo = repository_for_event or return
      repo.branches.find_by(name: event[:ref])&.destroy
    end
  end
end
