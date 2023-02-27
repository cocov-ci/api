# frozen_string_literal: true

# == Schema Information
#
# Table name: issues
#
#  id                     :bigint           not null, primary key
#  commit_id              :bigint           not null
#  kind                   :integer          not null
#  file                   :string           not null
#  uid                    :citext           not null
#  line_start             :integer          not null
#  line_end               :integer          not null
#  message                :string           not null
#  check_source           :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  ignored_at             :datetime
#  ignore_reason          :integer
#  ignored_by_user_id     :bigint
#  ignored_by_rule_id     :bigint
#  ignored_by_user_reason :string
#
# Indexes
#
#  index_issues_on_commit_id           (commit_id)
#  index_issues_on_ignored_by_rule_id  (ignored_by_rule_id)
#  index_issues_on_ignored_by_user_id  (ignored_by_user_id)
#  index_issues_on_uid                 (uid)
#  index_issues_on_uid_and_commit_id   (uid,commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#  fk_rails_...  (ignored_by_rule_id => issue_ignore_rules.id)
#  fk_rails_...  (ignored_by_user_id => users.id)
#
class Issue < ApplicationRecord
  include IssueFields

  enum ignore_reason: {
    by_user: 1,
    by_rule: 2
  }, _prefix: :ignored

  belongs_to :commit, counter_cache: true
  has_one :ignored_by_user, class_name: :user, required: false, dependent: nil
  has_one :ignored_by_rule, class_name: :issue_ignore_rule, required: false, dependent: nil

  validates :uid, presence: true, uniqueness: { scope: :commit_id }
  validates :ignored_by_user, presence: true, if: -> { ignored_by_user? }
  validates :ignored_by_rule, presence: true, if: -> { ignored_by_rule? }
end
