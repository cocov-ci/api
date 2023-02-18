# frozen_string_literal: true

class RemoveCheckStatusFromCommit < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        remove_column :commits, :checks_status
      end

      dir.down do
        add_column :commits, :checks_status, :integer, null: true
        Commit.includes(:check_set).all.each do |c|
          c.checks_status = c.check_set&.status || 0
          c.save!
        end
        change_column_null :commits, :checks_status, false
      end
    end
  end
end
