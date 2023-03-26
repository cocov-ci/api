# frozen_string_literal: true

class CreateCacheTools < ActiveRecord::Migration[7.0]
  def change
    create_table :cache_tools do |t|
      t.citext :name, null: false
      t.string :name_hash, null: false, index: true
      t.integer :size, null: false
      t.timestamp :last_used_at, index: true
      t.citext :engine, null: false, index: true
      t.string :mime, null: false

      t.timestamps
    end

    add_index :cache_tools, %i[name engine], unique: true
    add_index :cache_tools, %i[name_hash engine], unique: true
  end
end
