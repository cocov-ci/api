# frozen_string_literal: true

class AddLastUsedAtToTokens < ActiveRecord::Migration[7.0]
  def change
    add_column :user_tokens, :last_used_at, :timestamp, null: true, default: nil
    add_column :service_tokens, :last_used_at, :timestamp, null: true, default: nil
  end
end
