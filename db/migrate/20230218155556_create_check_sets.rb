# frozen_string_literal: true

class CreateCheckSets < ActiveRecord::Migration[7.0]
  def change
    create_table :check_sets do |t|
      t.references :commit, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false

      t.timestamps
    end
  end
end
