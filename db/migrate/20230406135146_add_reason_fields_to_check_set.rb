# frozen_string_literal: true

class AddReasonFieldsToCheckSet < ActiveRecord::Migration[7.0]
  def change
    change_table :check_sets, bulk: true do |t|
      t.column :error_kind, :integer, null: false, default: 0
      t.column :error_extra, :string
    end
  end
end
