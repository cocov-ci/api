# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.citext :login, null: false, index: { unique: true }
      t.integer :github_id, null: false, index: { unique: true }
      t.boolean :admin, null: false, default: false
      t.text :github_token, null: false
      t.text :github_scopes, null: false
      t.text :avatar_url, null: true

      t.timestamps
    end
  end
end
