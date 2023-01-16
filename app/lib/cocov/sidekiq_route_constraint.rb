# frozen_string_literal: true

module Cocov
  class SidekiqRouteConstraint
    def matches?(request)
      sid = request.session[:cocov_sidekiq_session_id]
      user = SidekiqRouteConstraint.user_for_session(sid)
      user&.admin? || false
    end

    def self.user_for_session(sid)
      return unless sid

      digest = OpenSSL::Digest::SHA256.hexdigest(sid)
      obj = Cocov::Redis.get_sidekiq_session(digest)
      return unless obj

      user_id = begin
        Cocov::Crypto.decrypt(Base64.decode64(obj))
      rescue StandardError
        nil
      end

      return if user_id.nil?

      User.find_by(id: user_id)
    end

    def self.generate_exchange_token(user)
      "csp_#{SecureRandom.hex(32)}".tap do |auth_id|
        digest = OpenSSL::Digest::SHA256.hexdigest(auth_id)
        obj_id = Base64.encode64(Cocov::Crypto.encrypt(user.id.to_s))
        Cocov::Redis.register_sidekiq_authorization(digest, obj_id)
      end
    end

    def self.session_for_exchange_token(token)
      return nil if token.empty? || !token.start_with?("csp_")

      digest = OpenSSL::Digest::SHA256.hexdigest(token)
      obj = Cocov::Redis.void_sidekiq_authorization(digest)
      return nil unless obj

      u = User.find_by(id: Cocov::Crypto.decrypt(Base64.decode64(obj)))
      return nil unless u&.admin?

      SecureRandom.hex(32).tap do |auth_id|
        digest = OpenSSL::Digest::SHA256.hexdigest(auth_id)
        obj_id = Base64.encode64(Cocov::Crypto.encrypt(u.id.to_s))
        Cocov::Redis.register_sidekiq_session(digest, obj_id)
      end
    end
  end
end
