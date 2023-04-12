# frozen_string_literal: true

module Cocov
  class Redis
    module Cached
      def authorize_cache_client(id, repo_name:, repo_id:)
        instance.set("cocov:cached:client:#{id}",
          { name: repo_name, id: repo_id }.to_json,
          ex: 3.hours)
      end

      def void_cache_client(id)
        instance.del("cocov:cached:client:#{id}")
      end

      def request_cache_eviction(repository_id, object_ids:)
        instance.rpush("cocov:cached:housekeeping_tasks", {
          task: "evict-artifact",
          task_id: SecureRandom.uuid,
          repository: repository_id,
          objects: object_ids
        }.to_json)
      end

      def request_cache_purge(repository_id)
        instance.rpush("cocov:cached:housekeeping_tasks", {
          task: "purge-repository",
          task_id: SecureRandom.uuid,
          repository: repository_id
        }.to_json)
      end

      def request_tool_eviction(object_ids:)
        instance.rpush("cocov:cached:housekeeping_tasks", {
          task: "evict-tool",
          task_id: SecureRandom.uuid,
          objects: object_ids
        }.to_json)
      end

      def request_tool_purge
        instance.rpush("cocov:cached:housekeeping_tasks", {
          task: "purge-tool",
          task_id: SecureRandom.uuid
        }.to_json)
      end
    end
  end
end
