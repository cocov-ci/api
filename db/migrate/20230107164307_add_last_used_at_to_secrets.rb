# frozen_string_literal: true

class AddLastUsedAtToSecrets < ActiveRecord::Migration[7.0]
  def change
    add_column :secrets, :last_used_at, :timestamp, null: true, default: nil
  end
end
