# frozen_string_literal: true

class DestroyRepositoryJob < ApplicationJob
  queue_as :default

  def perform(id)
    r = Repository.find(id)

    r.cache_artifacts.in_batches do |group|
      Cocov::Redis.request_cache_eviction(id, object_ids: group.pluck(:id))
    end

    ActiveRecord::Base.transaction do
      IssueHistory.where(repository: r).delete_all
      CoverageHistory.where(repository: r).delete_all
      r.destroy!
    end
  end
end
