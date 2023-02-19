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
    processing: 2,
    processed: 3,
    errored: 4,
    not_configured: 5,
    canceled: 6
  }

  def finished? = processed? || errored? || canceled?

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

  def wrap_up!
    # Make sure all checks have a valid status before continuing
    raise IncompatibleChildStatusError unless checks.all?(&:finished?)

    transaction do
      commit.reset_counters
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
      commit.create_github_status(:error, context: "cocov", description: "Checks were canceled")
      return
    end

    if checks.any?(&:errored?)
      errored!
      commit.create_github_status(:error, context: "cocov", description: "An internal error occurred")
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
