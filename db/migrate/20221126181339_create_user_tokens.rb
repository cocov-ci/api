# frozen_string_literal: true

class CreateUserTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :user_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :kind, null: false
      t.text :hashed_token, null: false, index: { unique: true }
      t.timestamp :expires_at

      t.timestamps
    end
  end
end
