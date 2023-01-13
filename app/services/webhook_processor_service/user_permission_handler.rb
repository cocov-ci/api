# frozen_string_literal: true

class WebhookProcessorService
  class UserPermissionHandler < BaseHandler
    wants :member
    wants :organization
    wants :membership

    def validate
      event_name != :organization ||
        %w[deleted renamed member_invited].exclude?(event[:action])
    end

    def handle
      user = user_for_event or return
      UpdateUserPermissionsJob.perform_later(user.id)
    end
  end
end
