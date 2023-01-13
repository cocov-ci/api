# frozen_string_literal: true

class AddGithubMemberIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :repository_members, :github_member_id
  end
end
