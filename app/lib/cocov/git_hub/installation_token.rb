# frozen_string_literal: true

module Cocov
  class GitHub
    class InstallationToken
      attr_accessor :token, :expires_at

      def initialize(data)
        @token = data[:token]
        @expires_at = Time.zone.parse(data[:expires_at])
      end

      def expired?
        @expires_at.past?
      end

      def to_json(*_args)
        { token: @token, expires_at: @expires_at.iso8601 }.to_json
      end
    end
  end
end
