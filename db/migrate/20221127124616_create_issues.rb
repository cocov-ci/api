# frozen_string_literal: true

class CreateIssues < ActiveRecord::Migration[7.0]
  def change
    create_table :issues do |t|
      t.references :commit, null: false, foreign_key: true
      t.references :assignee, null: true, foreign_key: { to_table: :users }
      t.integer :kind, null: false
      t.integer :status, null: false
      t.text :status_reason
      t.string :file, null: false
      t.citext :uid, null: false, index: true
      t.integer :line_start, null: false
      t.integer :line_end, null: false
      t.string :message, null: false
      t.string :check_source, null: false

      t.timestamps
    end

    add_index :issues, %i[uid commit_id], unique: true
  end
end
