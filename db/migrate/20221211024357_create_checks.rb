# frozen_string_literal: true

class CreateChecks < ActiveRecord::Migration[7.0]
  def change
    create_table :checks do |t|
      t.references :commit, null: false, foreign_key: true
      t.citext :plugin_name, null: false
      t.timestamp :started_at
      t.timestamp :finished_at
      t.integer :status, null: false
      t.text :error_output

      t.timestamps
    end

    add_index :checks, %i[commit_id plugin_name], unique: true
  end
end
