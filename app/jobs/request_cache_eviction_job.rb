# frozen_string_literal: true

class RequestCacheEvictionJob < ApplicationJob
  queue_as :default

  def perform(repo_id)
    repo = Repository.find(repo_id)
    size_delta = repo.cache_size - Cocov::REPOSITORY_CACHE_MAX_SIZE
    return unless size_delta.positive?

    to_evict = []
    total_size = 0

    repo.cache_artifacts.order(:last_used_at).in_batches(of: 10) do |group|
      group.each do |item|
        to_evict << item.id
        total_size += item.size

        break if total_size >= size_delta
      end

      break if total_size >= size_delta
    end

    logger.info "Evicting #{to_evict.length} item(s), reducing #{total_size} byte(s)"

    Cocov::Redis.request_cache_eviction(repo_id, object_ids: to_evict)
  end
end
