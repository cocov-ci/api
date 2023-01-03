# frozen_string_literal: true

class CreateCoverageHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :coverage_histories do |t|
      t.references :repository, null: false, foreign_key: true, index: true
      t.references :branch, null: false, foreign_key: true, index: true
      t.float :percentage, null: false

      t.timestamps
    end

    add_index :coverage_histories, :created_at
  end
end
