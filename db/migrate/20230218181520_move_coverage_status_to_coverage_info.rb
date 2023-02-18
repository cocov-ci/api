# frozen_string_literal: true

class MoveCoverageStatusToCoverageInfo < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        Commit.includes(:coverage).all.each do |commit|
          commit.reset_coverage! if commit.coverage.nil?

          commit.coverage.status = commit.coverage_status
          commit.save!
        end
      end

      dir.down do
        Commit.includes(:coverage).all.each do |commit|
          commit.coverage_status = commit.coverage.status
          commit.coverage.destroy! if commit.coverage.waiting?
          commit.save!
        end
      end
    end
  end
end
