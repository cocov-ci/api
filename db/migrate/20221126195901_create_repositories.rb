# frozen_string_literal: true

class CreateRepositories < ActiveRecord::Migration[7.0]
  def change
    create_table :repositories do |t|
      t.citext :name, null: false, index: { unique: true }
      t.text :description, null: true
      t.citext :default_branch, null: false
      t.text :token, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
