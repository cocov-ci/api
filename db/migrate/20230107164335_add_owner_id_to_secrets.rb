# frozen_string_literal: true

class AddOwnerIdToSecrets < ActiveRecord::Migration[7.0]
  def change
    add_reference :secrets, :owner, index: true, foreign_key: { to_table: :users }, null: true
    change_column_null :secrets, :owner_id, false, User.first&.id
  end
end
