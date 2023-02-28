# frozen_string_literal: true

# == Schema Information
#
# Table name: issue_ignore_rules
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  user_id       :bigint           not null
#  reason        :string
#  check_source  :string           not null
#  file          :string           not null
#  kind          :integer          not null
#  line_start    :integer          not null
#  line_end      :integer          not null
#  message       :string           not null
#  uid           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_issue_ignore_rules_on_repository_id          (repository_id)
#  index_issue_ignore_rules_on_uid                    (uid)
#  index_issue_ignore_rules_on_uid_and_repository_id  (uid,repository_id) UNIQUE
#  index_issue_ignore_rules_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :issue_ignore_rule do
    repository { nil }
    check_source { "rubocop" }
    kind { :style }
    file { "foo/bar.rb" }
    line_start { 1 }
    line_end { 1 }
    message { "something is wrong" }
    uid { SecureRandom.hex(32) }
  end
end
