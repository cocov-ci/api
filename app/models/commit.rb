# frozen_string_literal: true

# == Schema Information
#
# Table name: commits
#
#  id               :bigint           not null, primary key
#  repository_id    :bigint           not null
#  sha              :citext           not null
#  author_name      :string           not null
#  author_email     :string           not null
#  message          :text             not null
#  user_id          :bigint
#  issues_count     :integer
#  coverage_percent :integer
#  clone_status     :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  minimum_coverage :integer
#
# Indexes
#
#  index_commits_on_repository_id          (repository_id)
#  index_commits_on_sha                    (sha)
#  index_commits_on_sha_and_repository_id  (sha,repository_id) UNIQUE
#  index_commits_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#  fk_rails_...  (user_id => users.id)
#
class Commit < ApplicationRecord
  enum clone_status: { queued: 0, in_progress: 1, completed: 2, errored: 3 }, _prefix: :clone

  before_validation :ensure_statuses

  validates :author_email, presence: true
  validates :author_name, presence: true
  validates :sha, presence: true
  validates :message, presence: true

  belongs_to :repository
  belongs_to :user, optional: true

  has_one :coverage, class_name: :CoverageInfo, dependent: :destroy
  has_one :check_set, dependent: :destroy
  has_many :issues, dependent: :destroy

  has_many :checks, through: :check_set

  def create_github_status(status, context:, description: nil, url: nil)
    opts = { description:, target_url: url, context: }.compact
    Cocov::GitHub.app.create_status(
      "#{Cocov::GITHUB_ORGANIZATION_NAME}/#{repository.name}",
      sha,
      status.to_s,
      **opts
    )
  end

  def condensed_status
    status = [checks_status, coverage_status].map(&:to_sym)
    if status.all?(:processed)
      :green
    elsif status.any?(:errored)
      :red
    else
      :yellow
    end
  end

  def adjust_associated_user!
    return unless (email = UserEmail.find_by(email: author_email))

    update! user_id: email.user_id
  end

  def reset_check_set!
    check_set&.reset! || create_check_set!
  end

  def reset_coverage!(status:)
    coverage&.reset!(status:) || create_coverage!(status:)
  end

  def checks_status
    check_set&.status || "waiting"
  end

  def coverage_status
    coverage&.status || "waiting"
  end

  def reset_counters
    Commit.reset_counters(id, :issues)
    reload
  end

  private

  def ensure_statuses
    self.clone_status = :queued if clone_status.blank?
  end
end
