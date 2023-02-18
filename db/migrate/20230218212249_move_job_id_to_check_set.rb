class MoveJobIdToCheckSet < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        add_column :check_sets, :job_id, :string
        add_index :check_sets, :job_id, unique: true

        Commit.includes(:check_set).where.not(check_job_id: nil).each do |commit|
          commit.create_check_set! if commit.check_set.nil?
          commit.check_set.job_id = commit.check_job_id
          commit.check_set.save!
        end

        remove_column :commits, :check_job_id
      end

      dir.down do
        add_column :commits, :check_job_id, :string
        add_index :commits, :check_job_id, unique: true

        CheckSet.includes(:commit).where.not(job_id: nil).each do |check|
          check.commit.check_job_id = check.job_id
          check.commit.save!
        end

        remove_column :check_sets, :job_id
      end
    end
  end
end
