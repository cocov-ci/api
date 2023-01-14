# frozen_string_literal: true

class UpdateUserPermissionsJob < ApplicationJob
  queue_as :default

  def perform(uid)
    user = User.find(uid)
    local = RepositoryMember
      .where(github_member_id: user.github_id)
      &.pluck(:id, :repository_id, :level)

    remote_data = Cocov::GitHub
      .for_user(user)
      .organization_repositories(Cocov::GITHUB_ORGANIZATION_NAME)

    remote_permissions = remote_data
      .to_h { [_1.id, RepositoryMember.level_from_github(_1.permissions).to_s] }

    known_remote = remote_data
      .map(&:id)
      .each_slice(400)
      .map { Repository.where(github_id: _1).pluck(:github_id, :id) }
      .flatten(1)
      .to_h

    to_add = []
    to_remove = []
    to_update = []

    # To add
    known_remote.each do |remote_id, local_id|
      next if local.find { _1.second == local_id }

      to_add << { repository_id: local_id, level: remote_permissions[remote_id], github_member_id: user.github_id }
    end

    # To remove
    known_remote_local_ids = known_remote.values
    local.each do |id, repo_id, _level|
      next if known_remote_local_ids.include? repo_id

      to_remove << id
    end

    # To update
    local.each do |id, repo_id, level|
      remote_repo_id = known_remote.find { |_k, v| v == repo_id }&.first or next
      perm = remote_permissions[remote_repo_id]
      next if level == perm

      to_update << { id:, level: perm }
    end

    ActiveRecord::Base.transaction do
      to_remove.each_slice(500) do |ids|
        RepositoryMember
          .where(id: ids)
          .delete_all
      end

      to_add.each_slice(500) { |objs| RepositoryMember.insert_all(objs) }

      to_update.each do |obj|
        RepositoryMember.find(obj[:id]).update(level: obj[:level])
      end
    end
  end
end
