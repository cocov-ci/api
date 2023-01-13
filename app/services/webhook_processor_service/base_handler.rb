# frozen_string_literal: true

class WebhookProcessorService
  class BaseHandler
    def self.wants(*what)
      WebhookProcessorService.register(self, what)
    end

    attr_reader :event, :event_name

    def initialize(event_name, event)
      @event = event.dup
      @event_name = event_name
    end

    def handle
      raise NotImplementedError
    end

    def validate
      true
    end

    def repository_for_event
      gid = event.dig(:repository, :id)
      return unless gid

      Repository.find_by(github_id: gid)
    end

    def user_for_event
      gid = event.dig(:member, :id) || event.dig(:membership, :user, :id)
      return unless gid

      User.find_by(github_id: gid)
    end
  end
end
