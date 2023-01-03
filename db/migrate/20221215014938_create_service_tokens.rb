# frozen_string_literal: true

class CreateServiceTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :service_tokens do |t|
      t.text :hashed_token, index: { unique: true }, null: false
      t.text :description, null: false
      t.references :owner, index: true, foreign_key: { to_table: :users }, null: false
      t.timestamps
    end
  end
end
