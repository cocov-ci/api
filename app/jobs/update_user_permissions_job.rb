# frozen_string_literal: true

class UpdateUserPermissionsJob < ApplicationJob
  queue_as :default

  def perform(id)
    user = User.find(id)
    local = RepositoryMember
      .where(github_member_id: user.github_id)
      &.pluck(:repository_id)

    remote = Cocov::GitHub
      .for_user(user)
      .organization_repositories(Cocov::GITHUB_ORGANIZATION_NAME)
      &.map(&:id)
      &.each_slice(400)
      &.map { Repository.where(github_id: _1).pluck(:id) }
      &.flatten || []

    to_remove = (local - remote)
    to_add = (remote - local).map { { github_member_id: user.github_id, repository_id: _1 } }

    ActiveRecord::Base.transaction do
      to_remove.each_slice(500) do |ids|
        RepositoryMember
          .where(repository_id: ids, github_member_id: user.github_id)
          .delete_all
      end

      to_add.each_slice(500) { |objs| RepositoryMember.insert_all(objs) }
    end
  end
end
