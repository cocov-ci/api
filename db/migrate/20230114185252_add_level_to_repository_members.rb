# frozen_string_literal: true

class AddLevelToRepositoryMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :repository_members, :level, :integer
  end
end
