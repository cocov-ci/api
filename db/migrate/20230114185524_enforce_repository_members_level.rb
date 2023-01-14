# frozen_string_literal: true

class EnforceRepositoryMembersLevel < ActiveRecord::Migration[7.0]
  def change
    RepositoryMember.transaction do
      RepositoryMember.update_all level: :user
    end

    change_column_null :repository_members, :level, false

    User.all.each do |u|
      # Update permissions
      UpdateUserPermissionsJob.perform_later(u.id)
    end
  end
end
