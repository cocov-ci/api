# frozen_string_literal: true

class AddCancelingToCheckSet < ActiveRecord::Migration[7.0]
  def change
    add_column :check_sets, :canceling, :boolean, default: false, null: false
  end
end
