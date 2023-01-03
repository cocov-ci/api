# frozen_string_literal: true

# == Schema Information
#
# Table name: issues
#
#  id            :bigint           not null, primary key
#  commit_id     :bigint           not null
#  assignee_id   :bigint
#  kind          :integer          not null
#  status        :integer          not null
#  status_reason :text
#  file          :string           not null
#  uid           :citext           not null
#  line_start    :integer          not null
#  line_end      :integer          not null
#  message       :string           not null
#  check_source  :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_issues_on_assignee_id        (assignee_id)
#  index_issues_on_commit_id          (commit_id)
#  index_issues_on_uid                (uid)
#  index_issues_on_uid_and_commit_id  (uid,commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (commit_id => commits.id)
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
