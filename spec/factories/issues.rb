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
#  index_issues_on_ignored_at         (ignored_at)
#  index_issues_on_uid                (uid)
#  index_issues_on_uid_and_commit_id  (uid,commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#  fk_rails_...  (ignore_rule_id => issue_ignore_rules.id)
#  fk_rails_...  (ignore_user_id => users.id)
#
FactoryBot.define do
  factory :issue do
    commit { nil }
    check_source { "rubocop" }
    kind { :style }
    file { "foo/bar.rb" }
    line_start { 1 }
    line_end { 1 }
    message { "something is wrong" }
    uid { SecureRandom.hex(32) }

    trait :with_commit do
      commit { create(:commit, :with_repository) }
    end
  end
end
