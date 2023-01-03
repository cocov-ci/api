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
require "rails_helper"

RSpec.describe Issue do
  subject { build(:issue, :with_commit) }

  it_behaves_like "a validated model", %i[
    check_source
    file
    kind
    line_end
    line_start
    message
    commit
  ]
end
