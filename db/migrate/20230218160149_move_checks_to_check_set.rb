# frozen_string_literal: true

class MoveChecksToCheckSet < ActiveRecord::Migration[7.0]
  def change
    reversible do |direction|
      direction.up do
        Check
          .where(check_set: nil)
          .group_by(&:commit_id)
          .each do |cid, checks|
            commit = Commit.find(cid)
            set = CheckSet.create!(commit:, status: commit.checks_status)
            checks.each do |check|
              check.check_set = set
              check.save!
            end
          end
      end

      direction.down do
        Check.update_all check_set_id: nil
        CheckSet.destroy_all
      end
    end
  end
end
