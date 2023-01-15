# frozen_string_literal: true

class DestroyRepositoryJob < ApplicationJob
  queue_as :default

  def perform(id)
    r = Repository.find(id)
    ActiveRecord::Base.transaction do
      IssueHistory.where(repository: r).delete_all
      CoverageHistory.where(repository: r).delete_all
      r.destroy!
    end
  end
end
