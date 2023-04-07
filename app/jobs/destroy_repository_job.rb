# frozen_string_literal: true

class DestroyRepositoryJob < ApplicationJob
  queue_as :default

  def perform(id)
    r = Repository.find(id)

    Cocov::Redis.request_cache_purge(r.id) if Cocov::CACHE_SERVICE_URL.present?

    ActiveRecord::Base.transaction do
      CacheArtifact.where(repository: r).delete_all
      IssueHistory.where(repository: r).delete_all
      CoverageHistory.where(repository: r).delete_all
      r.destroy!
    end
  end
end
