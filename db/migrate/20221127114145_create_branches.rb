# frozen_string_literal: true

class CreateBranches < ActiveRecord::Migration[7.0]
  def change
    create_table :branches do |t|
      t.references :repository, null: false, foreign_key: true
      t.citext :name, null: false
      t.integer :issues
      t.integer :coverage

      t.timestamps
    end

    add_index :branches, %i[repository_id name], unique: true
  end
end
