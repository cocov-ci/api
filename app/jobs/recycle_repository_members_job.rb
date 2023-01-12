class RecycleRepositoryMembersJob < ApplicationJob
  queue_as :default

  def perform(repo_id)
    repo = Repository.find(repo_id)
    collabs = Cocov::GitHub.app.collaborators(repo.github_id)
    ActiveRecord::Base.transaction do
      repo.members.delete_all
      to_insert = collabs.map { { github_member_id: _1.id, repository_id: repo_id } )
      RepositoryMember.insert_all! *to_insert
    end
  end
end
