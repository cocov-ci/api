# frozen_string_literal: true

module V1
  class GithubEventsController < V1Controller
    before_action :validate_signature
    before_action :validate_event
    around_action :ignore_duplicated_events

    def create
      key = [@event_name, @event[:action]&.to_sym].compact
      WebhookProcessorService.call(key, @event)
      head :ok
    end

    private

    def validate_event
      @event_name = request.env["HTTP_X_GITHUB_EVENT"]
      return head :bad_request if @event_name.blank?

      @event_name = @event_name.to_sym

      request.body.rewind
      @event = JSON.parse(request.body.read, symbolize_names: true).with_indifferent_access
    end

    def ignore_duplicated_events
      event_id = request.env["HTTP_X_GITHUB_DELIVERY"]
      return head :bad_request if event_id.blank?

      event_key = "github:event:delivery:#{event_id}"
      Cocov::Redis.lock("github:delivery:#{event_id}", 1.minute) do
        head :ok and return if Cocov::Redis.instance.exists? event_key

        yield

        Cocov::Redis.instance.set event_key, 1, ex: 2.days if response.successful?
      end
    end

    def validate_signature
      return if Cocov::GITHUB_WEBHOOK_SECRET_KEY.blank?

      request.body.rewind
      hex_digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), Cocov::GITHUB_WEBHOOK_SECRET_KEY,
        request.body.read)
      head :forbidden unless Rack::Utils.secure_compare("sha256=#{hex_digest}", request.env["HTTP_X_HUB_SIGNATURE_256"])
    end
  end
end
