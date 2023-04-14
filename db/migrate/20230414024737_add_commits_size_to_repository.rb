# frozen_string_literal: true

class AddCommitsSizeToRepository < ActiveRecord::Migration[7.0]
  def change
    add_column :repositories, :commits_size, :integer, limit: 8, default: 0, null: false
  end
end
