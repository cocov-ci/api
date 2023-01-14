# frozen_string_literal: true

class UpdateRepoPermissionsJob < ApplicationJob
  queue_as :default

  def perform(id)
    repo = Repository.find(id)
    local = repo.members.pluck(:github_member_id, :id, :level)
    remote = Cocov::GitHub.app
      .collaborators(repo.github_id)
      .map { { id: _1.id, level: RepositoryMember.level_from_github(_1.permissions).to_s } }

    to_add = []
    to_remove = []
    to_update = []

    # To add
    remote.each do |u|
      next if local.find { _1.first == u[:id] }

      to_add << { repository_id: repo.id, github_member_id: u[:id], level: u[:level] }
    end

    # To remove
    local.each do |remote_id, local_id, _level|
      next if remote.find { _1[:id] == remote_id }

      to_remove << local_id
    end

    # To update
    local.each do |remote_id, local_id, level|
      remote_user = remote.find { _1[:id] == remote_id } or next
      next if remote_user[:level] == level

      to_update << { id: local_id, level: remote_user[:level] }
    end

    ActiveRecord::Base.transaction do
      to_remove.each_slice(500) do |ids|
        RepositoryMember.where(id: ids).delete_all
      end

      to_add.each_slice(500) { |objs| RepositoryMember.insert_all(objs) }

      to_update.each do |obj|
        RepositoryMember.find(obj[:id]).update(level: obj[:level])
      end
    end
  end
end
