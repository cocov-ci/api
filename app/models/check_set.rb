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
#  job_id      :string
#  canceling   :boolean          default(FALSE), not null
#
# Indexes
#
#  index_check_sets_on_commit_id  (commit_id) UNIQUE
#  index_check_sets_on_job_id     (job_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
class CheckSet < ApplicationRecord
  class IncompatibleChildStatusError < StandardError
    def initialize
      super("not all checks have a valid finished status")
    end
  end

  class StillRunningError < StandardError
    def initialize
      super("Cannot re-run checks while they are still running")
    end
  end

  enum status: {
    waiting: 0,
    queued: 1,
    in_progress: 2,
    completed: 3,
    errored: 4,
    not_configured: 5,
    canceled: 6
  }

  def finished? = completed? || errored? || canceled?

  def canceling!
    self.canceling = true
    save!
  end

  validates :job_id, uniqueness: true, if: -> { job_id.present? }
  belongs_to :commit
  has_many :checks, dependent: :destroy

  before_validation :ensure_status

  def reset!
    transaction do
      self.canceling = false
      self.status = :waiting
      self.started_at = Time.zone.now
      save!
      checks.destroy_all
      commit.issues.destroy_all
    end
    true
  end

  def rerun!
    locking(timeout: 5.seconds) do
      raise StillRunningError unless reload.finished?

      ChecksRunService.call(commit)
    end

    true
  end

  def cancel!
    locking(timeout: 5.seconds) do
      reload
      next if canceling? || finished?

      canceling!
      Cocov::Redis.instance.publish("cocov:checks_control", {
        check_set_id: id,
        job_id:,
        operation: :cancel
      }.to_json)
    end

    true
  end

  def mark_processing!
    locking(timeout: 5.seconds) do
      reload
      next if canceling? || finished?

      in_progress!
    end

    true
  end

  def wrap_up!
    # Make sure all checks have a valid status before continuing
    raise IncompatibleChildStatusError unless checks.all?(&:finished?)

    transaction do
      commit.reset_counters!
      self.finished_at = Time.zone.now

      next if canceling?

      IssueHistory.register_history! commit, commit.issues_count
      commit.repository.branches.where(head_id: commit.id).find_each do |br|
        br.issues = commit.issues_count
        br.save!
      end
    end

    if canceling?
      canceled!
      commit.create_github_status(:error,
        context: "cocov",
        description: "Checks were canceled",
        url: commit.checks_url
      )
      return
    end

    if checks.any?(&:errored?)
      errored!
      commit.create_github_status(:error,
        context: "cocov",
        description: "An internal error occurred",
        url: commit.checks_url
      )
      return
    end

    completed!
    commit.update_github_issue_count_status!
  end

  def ensure_status
    self.status = :waiting if status.blank?
  end
end
