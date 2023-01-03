# frozen_string_literal: true

class CreateIssueHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :issue_histories do |t|
      t.references :repository, null: false, foreign_key: true, index: true
      t.references :branch, null: false, foreign_key: true, index: true
      t.integer :quantity, null: false

      t.timestamps
    end

    add_index :issue_histories, :created_at
  end
end
