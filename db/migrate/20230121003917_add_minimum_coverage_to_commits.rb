# frozen_string_literal: true

class AddMinimumCoverageToCommits < ActiveRecord::Migration[7.0]
  def change
    add_column :commits, :minimum_coverage, :integer
  end
end
