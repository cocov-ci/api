# frozen_string_literal: true

class RemoveAssigneeIdFromIssues < ActiveRecord::Migration[7.0]
  def change
    remove_reference :issues, :assignee, null: true, foreign_key: { to_table: :users }
  end
end
