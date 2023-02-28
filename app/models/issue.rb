# frozen_string_literal: true

# == Schema Information
#
# Table name: issues
#
#  id                 :bigint           not null, primary key
#  commit_id          :bigint           not null
#  kind               :integer          not null
#  file               :string           not null
#  uid                :citext           not null
#  line_start         :integer          not null
#  line_end           :integer          not null
#  message            :string           not null
#  check_source       :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ignored_at         :datetime
#  ignore_source      :integer
#  ignore_user_id     :bigint
#  ignore_rule_id     :bigint
#  ignore_user_reason :string
#
# Indexes
#
#  index_issues_on_commit_id          (commit_id)
#  index_issues_on_ignore_rule_id     (ignore_rule_id)
#  index_issues_on_ignore_user_id     (ignore_user_id)
#  index_issues_on_uid                (uid)
#  index_issues_on_uid_and_commit_id  (uid,commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#  fk_rails_...  (ignore_rule_id => issue_ignore_rules.id)
#  fk_rails_...  (ignore_user_id => users.id)
#
class Issue < ApplicationRecord
  include IssueFields

  after_update :conditionally_update_repo_counter_cache
  after_destroy :update_repo_counter_cache
  after_save :update_repo_counter_cache

  enum ignore_source: {
    user: 1,
    rule: 2
  }, _prefix: :ignored_by

  # counter_cache is not here since we need conditions on it.
  # See #update_repo_counter_cache
  belongs_to :commit
  belongs_to :ignore_user, class_name: :User, required: false
  belongs_to :ignore_rule, class_name: :IssueIgnoreRule, required: false

  validates :uid, presence: true, uniqueness: { scope: :commit_id }
  validates :ignore_user, presence: true, if: -> { ignored_by_user? }
  validates :ignore_rule, presence: true, if: -> { ignored_by_rule? }

  def ignored? = !ignored_at.nil?

  def ignore!(user:, reason:)
    self.ignored_at = Time.zone.now
    self.ignore_source = :user
    self.ignore_user = user
    self.ignore_user_reason = reason
    save!
  end

  def ignore_permanently!(user:, reason:)
    transaction do
      self.ignored_at = Time.zone.now
      self.ignore_source = :rule
      self.ignore_rule = IssueIgnoreRule.create_from!(issue: self, user:, reason:)
      save!
    end
  end

  def conditionally_update_repo_counter_cache
    update_repo_counter_cache if saved_change_to_ignored_at?
  end

  def update_repo_counter_cache
    commit.issues_count = Issue.count_for_commit(commit_id)
    commit.save
  end

  def ignored_by
    @ignored_by ||= if ignored_by_user?
      ignore_user
    else
      ignore_rule.user
    end
  end

  def ignore_reason
    @ignore_reason ||= if ignored_by_user?
      ignore_user_reason
    else
      ignore_rule.reason
    end
  end

  def clean_ignore!
    self.ignored_at = nil
    self.ignore_source = nil
    self.ignore_user_id = nil
    self.ignore_rule_id = nil
    self.ignore_user_reason = nil
    save!
  end

  def self.count_for_commit(id) = where("ignored_at IS NULL AND commit_id = ?", id).count
end
