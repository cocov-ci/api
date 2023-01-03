# frozen_string_literal: true

class CreateCommits < ActiveRecord::Migration[7.0]
  def change
    create_table :commits do |t|
      t.references :repository, null: false, foreign_key: true
      t.citext :sha, null: false, index: true
      t.string :author_name, null: false
      t.string :author_email, null: false
      t.text :message, null: false
      t.references :user, null: true, foreign_key: true
      t.integer :checks_status, null: false
      t.integer :coverage_status, null: false
      t.integer :issues_count
      t.integer :coverage_percent
      t.integer :clone_status, null: false
      t.string :check_job_id, index: true

      t.timestamps
    end

    add_index :commits, %i[sha repository_id], unique: true
  end
end
