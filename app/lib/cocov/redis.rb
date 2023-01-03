# frozen_string_literal: true

module Cocov
  class Redis
    class LockFailedError < StandardError; end
    CACHED_FILE_EXPIRATION = 7.days

    class << self
      # :nocov:

      def instance
        @instance ||= ::Redis.new(url: Cocov::REDIS_URL)
      end

      def cache
        return nil if Cocov::REDIS_CACHE_URL.blank?

        @cache ||= ::Redis.new(url: Cocov::REDIS_CACHE_URL)
      end

      # :nocov:

      def json_parser(**opts)
        ->(data) { JSON.parse(data, **opts) }
      end

      def get_json(key, delete: false)
        data = if delete
                 instance.getdel(key)
               else
                 instance.get(key)
               end
        return nil if data.nil?

        data = JSON.parse(data, symbolize_names: true)
        data = data.with_indifferent_access if data.is_a? Hash
        data
      end

      def cached_value(key, ex: 1.day, parse: nil)
        raise ArgumentError, "parse must be either nil, or a Proc" if !parse.nil? && !parse.is_a?(Proc)

        return yield if cache.nil?

        data = cache.getex(key, ex:)
        if data.nil?
          data = yield
          cache.set(key, data, ex:)
        else
          data = parse[data] unless parse.nil?
        end
        data
      end

      def cached_file(key, &)
        cached_value(key, ex: CACHED_FILE_EXPIRATION, &)
      end

      def make_authentication_keys
        oauth_state = SecureRandom.hex(21)
        auth_id = SecureRandom.hex(21)
        instance.set("auth:#{auth_id}", { state: oauth_state }.to_json, ex: 1.hour)

        {
          id: auth_id,
          state: oauth_state
        }
      end

      def get_authentication_state(id)
        get_json("auth:#{id}", delete: true)&.dig(:state)
      end

      def lock(resource, timeout)
        timeout = timeout.to_i * 1000 if timeout.is_a? ActiveSupport::Duration
        manager = Redlock::Client.new([REDIS_URL])
        lock = manager.lock("locks:#{resource}", timeout)
        raise LockFailedError, "Could not obtain exclusive access to resource `#{resource}'" unless lock

        begin
          yield
        ensure
          manager.unlock(lock)
        end
      end
    end
  end
end
