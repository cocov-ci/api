# frozen_string_literal: true

module Cocov
  class Redis
    extend Redis::Caching

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

      def register_secret_authorization(id, obj)
        # TODO: should we hold it unused for 7 days? How long should jobs be
        # enqueued for?
        instance.set("cocov:secret_auth:#{id}", obj, ex: 7.days)
      end

      def void_secret_authorization(id)
        lock("secret_auth:#{id}", 10.seconds) do
          instance.getdel("cocov:secret_auth:#{id}")
        end
      end

      def register_sidekiq_authorization(id, obj)
        instance.set("cocov:sidekiq_auth:#{id}", obj, ex: 1.minute)
      end

      def void_sidekiq_authorization(id)
        lock("sidekiq_auth:#{id}", 10.seconds) do
          instance.getdel("cocov:sidekiq_auth:#{id}")
        end
      end

      def register_sidekiq_session(id, user)
        instance.set("cocov:sidekiq_session:#{id}", user, ex: 10.minutes)
      end

      def get_sidekiq_session(id)
        instance.getex("cocov:sidekiq_session:#{id}", ex: 10.minutes)
      end

      def authorize_cache_client(id, repo_name:)
        instance.set("cocov:cached:client:#{id}", repo_name, ex: 3.hours)
      end

      def void_cache_client(id)
        instance.del("cocov:cached:client:#{id}")
      end

      def request_cache_eviction(repository_id, object_ids:)
        instance.rpush("cocov:cached:housekeeping_tasks", {
          task: :evict,
          task_id: SecureRandom.uuid,
          repository: repository_id,
          objects: object_ids
        }.to_json)
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
