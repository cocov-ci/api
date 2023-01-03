# frozen_string_literal: true

class CreateSecrets < ActiveRecord::Migration[7.0]
  def change
    create_table :secrets do |t|
      t.integer :scope, null: false, index: true
      t.citext :name, null: false, index: true
      t.references :repository, foreign_key: true, index: true
      t.binary :secure_data, null: false

      t.timestamps
    end

    add_index :secrets, %i[scope name repository_id], unique: true
  end
end
