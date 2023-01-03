# frozen_string_literal: true

class CreateCoverageFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :coverage_files do |t|
      t.references :coverage_info, null: false, foreign_key: true
      t.string :file, null: false
      t.integer :percent_covered, null: false
      t.binary :raw_data, null: false
      t.integer :lines_missed, null: false
      t.integer :lines_covered, null: false
      t.integer :lines_total, null: false

      t.timestamps
    end
  end
end
