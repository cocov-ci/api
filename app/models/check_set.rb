# frozen_string_literal: true

# == Schema Information
#
# Table name: check_sets
#
#  id          :bigint           not null, primary key
#  commit_id   :bigint           not null
#  status      :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  finished_at :datetime
#  started_at  :datetime
#
# Indexes
#
#  index_check_sets_on_commit_id  (commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
class CheckSet < ApplicationRecord
  class InconsistentCheckStatusError < StandardError; end

  enum status: {
    waiting: 0,
    queued: 1,
    processing: 2,
    processed: 3,
    errored: 4,
    not_configured: 5
  }

  belongs_to :commit
  has_many :checks, dependent: :destroy

  before_validation :ensure_status

  def reset!
    transaction do
      self.status = :waiting
      self.started_at = Time.zone.now
      checks.destroy_all
      commit.issues.destroy_all
    end
    true
  end

  def wrap_up!

    # Make sure all checks have a valid status before continuing
    unless checks.all?(&:finished?)
      raise InconsistentCheckStatusError, "not all checks have a valid finished status"
    end

    transaction do
      commit.reset_counters
      IssueHistory.register_history! commit, commit.issues_count
      self.finished_at = Time.zone.now
      commit.repository.branches.where(head_id: commit.id).each do |br|
        br.issues = commit.issues_count
        br.save!
      end
    end

    if checks.any?(&:errored?)
      errored!
      commit.create_github_status(:failure, context: "cocov", description: "An internal error occurred")
      return
    end

    processed!
    if commit.issues_count.zero?
      commit.create_github_status(:success, context: "cocov", description: "No issues detected")
      return
    end

    qty = commit.issues_count

    commit.create_github_status(:failure,
      context: "cocov",
      description: "#{qty} #{"issue".pluralize(qty)} detected",
      url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/issues")
  end

  def ensure_status
    self.status = :waiting if status.blank?
  end
end
