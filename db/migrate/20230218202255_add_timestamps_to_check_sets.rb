class AddTimestampsToCheckSets < ActiveRecord::Migration[7.0]
  def change
    add_column :check_sets, :finished_at, :timestamp
    add_column :check_sets, :started_at, :timestamp
  end
end
