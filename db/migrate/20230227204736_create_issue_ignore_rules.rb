# frozen_string_literal: true

class CreateIssueIgnoreRules < ActiveRecord::Migration[7.0]
  def change
    create_table :issue_ignore_rules do |t|
      t.references :repository, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :reason

      # Basically a copy of the original issue
      t.string :check_source, null: false
      t.string :file, null: false
      t.integer :kind, null: false
      t.integer :line_start, null: false
      t.integer :line_end, null: false
      t.string :message, null: false
      t.string :uid, null: false, index: true

      t.timestamps
    end

    add_index :issue_ignore_rules, %i[uid repository_id], unique: true
    add_column :repositories, :issue_ignore_rules_count, :integer, null: false, default: 0
  end
end
