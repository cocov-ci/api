# frozen_string_literal: true

class RemoveCoverageStatusFromCommit < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        remove_column :commits, :coverage_status
      end

      dir.down do
        add_column :commits, :coverage_status, :integer, null: true
        Commit.all.each do |commit|
          commit.coverage_status = commit.coverage&.status || 0
          commit.save!
        end
        change_column_null :commits, :coverage_status, false
      end
    end
  end
end
