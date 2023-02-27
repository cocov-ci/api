# frozen_string_literal: true

class AddIgnoreFieldsToIssues < ActiveRecord::Migration[7.0]
  def change
    change_table :issues, bulk: true do |t|
      t.timestamp :ignored_at, null: true
      t.integer :issues, :ignore_reason, null: true

      t.reference :ignored_by_user, null: true, foreign_key: { to_table: :users }
      t.reference :ignored_by_rule, null: true, foreign_key: { to_table: :issue_ignore_rules }
      t.string :ignored_by_user_reason, :string, null: true
    end

    change_table :issues, bulk: true do |t|
      t.remove :status, type: :integer, null: false
      t.remove :status_reason, type: :text
    end
  end
end
