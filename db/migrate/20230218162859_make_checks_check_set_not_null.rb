# frozen_string_literal: true

class MakeChecksCheckSetNotNull < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        change_column_null :checks, :check_set_id, false
        remove_column(:checks, :commit_id)
      end

      dir.down do
        change_column_null :checks, :check_set_id, true
        add_reference(:checks, :commit, null: true)
        Check.includes(:check_set).all.each do |c|
          c.commit_id = c.check_set.commit_id
          c.save!
        end
        change_column_null :checks, :commit_id, true
      end
    end
  end
end
