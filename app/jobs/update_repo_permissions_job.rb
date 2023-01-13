# frozen_string_literal: true

class UpdateRepoPermissionsJob < ApplicationJob
  queue_as :default

  def perform(id)
    repo = Repository.find(id)
    local = repo.members.pluck(:github_member_id)
    remote = Cocov::GitHub.app.collaborators(repo.github_id).map(&:id)

    to_remove = (local - remote)
    to_add = (remote - local).map { { github_member_id: _1, repository_id: repo.id } }

    ActiveRecord::Base.transaction do
      to_remove.each_slice(500) do |ids|
        RepositoryMember.where(repository_id: repo.id, github_member_id: ids).delete_all
      end

      to_add.each_slice(500) { |objs| RepositoryMember.insert_all(objs) }
    end
  end
end
