# frozen_string_literal: true

class AddIgnoreFieldsToIssues < ActiveRecord::Migration[7.0]
  def change
    change_table :issues, bulk: true do |t|
      t.timestamp :ignored_at, null: true
      t.integer :ignore_source, null: true

      t.references :ignore_user, null: true, foreign_key: { to_table: :users }
      t.references :ignore_rule, null: true, foreign_key: { to_table: :issue_ignore_rules }
      t.string :ignore_user_reason, null: true
    end

    change_table :issues, bulk: true do |t|
      t.remove :status, type: :integer, null: false, default: 0
      t.remove :status_reason, type: :text
    end
  end
end
