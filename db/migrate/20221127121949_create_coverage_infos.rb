# frozen_string_literal: true

class CreateCoverageInfos < ActiveRecord::Migration[7.0]
  def change
    create_table :coverage_infos do |t|
      t.references :commit, null: false, foreign_key: true, index: { unique: true }
      t.float :percent_covered
      t.integer :lines_total
      t.integer :lines_covered
      t.integer :status, null: false

      t.timestamps
    end
  end
end
