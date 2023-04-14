class ComputeRepositoryCommitsSizeJob < ApplicationJob
  queue_as :default

  def perform(repo_id)
    r = Repository.find(repo_id)
    r.commits_size = r.commits.sum(:clone_size)
    r.save!
  end
end
