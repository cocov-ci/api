# frozen_string_literal: true

class AddCloneSizeToCommits < ActiveRecord::Migration[7.0]
  def change
    add_column :commits, :clone_size, :integer, limit: 8
  end
end
