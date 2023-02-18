# frozen_string_literal: true

class AddTimestampsToCheckSets < ActiveRecord::Migration[7.0]
  def change
    change_table :check_sets, bulk: true do |t|
      t.add_column :finished_at, :timestamp
      t.add_column :started_at, :timestamp
    end
  end
end
