# frozen_string_literal: true

class AddHeadToBranch < ActiveRecord::Migration[7.0]
  def change
    add_reference :branches, :head, index: true, null: true, foreign_key: { to_table: :commits }
  end
end
