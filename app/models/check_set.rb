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
#  error_kind  :integer          default(NULL), not null
#  error_extra :string
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

  enum error_kind: {
    no_error: 1,
    commit_fetch_failed: 2,
    manifest_root_must_be_mapping: 3,
    manifest_missing_version: 4,
    manifest_version_type_mismatch: 5,
    manifest_version_unsupported: 6,
    manifest_unknown_secret: 7,
    manifest_duplicated_mount_destination: 8,
    manifest_invalid_mount_source: 9,
    manifest_invalid_or_missing_data: 10
  }, _prefix: :error

  USER_VISIBLE_ERROR_KINDS = %i[
    manifest_unknown_secret
    manifest_duplicated_mount_destination
    manifest_invalid_mount_source
    manifest_invalid_or_missing_data
  ].freeze

  enum status: {
    waiting: 0,
    queued: 1,
    in_progress: 2,
    completed: 3,
    errored: 4,
    not_configured: 5,
    canceled: 6,
    failure: 7
  }

  def finished? = completed? || errored? || canceled? || failure?

  def canceling!
    self.canceling = true
    save!
  end

  validates :job_id, uniqueness: true, if: -> { job_id.present? }
  belongs_to :commit
  has_many :checks, dependent: :destroy

  before_validation :ensure_status, :cleanup_user_visible_errors

  def reset!
    transaction do
      self.canceling = false
      self.status = :waiting
      self.started_at = Time.zone.now
      self.error_kind = :no_error
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
      commit.notify_check_status(:canceled)
      return
    end

    if checks.any?(&:errored?)
      errored!
      commit.notify_check_status(:internal_error)
      return
    end

    completed!
    commit.update_github_issue_count_status!
  end

  def ensure_status
    self.status = :waiting if status.blank?
    self.error_kind = :no_error if error_kind.blank?
  end

  def cleanup_user_visible_errors
    return if error_no_error?

    self.error_extra = nil unless USER_VISIBLE_ERROR_KINDS.include? error_kind.to_sym
  end
end
