# frozen_string_literal: true

class AddTimestampsToCheckSets < ActiveRecord::Migration[7.0]
  def change
    change_table :check_sets, bulk: true do |t|
      t.column :finished_at, :timestamp
      t.column :started_at, :timestamp
    end
  end
end
