# frozen_string_literal: true

class CreateRepositoryMembers < ActiveRecord::Migration[7.0]
  def change
    create_table :repository_members do |t|
      t.references :repository, null: false, foreign_key: true
      t.integer :github_member_id, null: false

      t.timestamps
    end

    add_index :repository_members, %i[repository_id github_member_id], unique: true
  end
end
