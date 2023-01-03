# frozen_string_literal: true

class CreatePrivateKeys < ActiveRecord::Migration[7.0]
  def change
    create_table :private_keys do |t|
      t.integer :scope, null: false, index: true
      t.references :repository, foreign_key: true, index: true
      t.citext :name, null: false, index: true
      t.binary :encrypted_key, null: false
      t.text :digest, null: false

      t.timestamps
    end

    add_index :private_keys, %i[scope name repository_id], unique: true
  end
end
