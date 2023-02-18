# frozen_string_literal: true

class AddCheckSetToCheck < ActiveRecord::Migration[7.0]
  def change
    add_reference :checks, :check_set, null: true, foreign_key: true
    add_index :checks, %i[plugin_name check_set_id], unique: true
  end
end
