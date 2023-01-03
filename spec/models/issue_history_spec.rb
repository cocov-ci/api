# frozen_string_literal: true

# == Schema Information
#
# Table name: issue_histories
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  branch_id     :bigint           not null
#  quantity      :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_issue_histories_on_branch_id      (branch_id)
#  index_issue_histories_on_created_at     (created_at)
#  index_issue_histories_on_repository_id  (repository_id)
#
# Foreign Keys
#
#  fk_rails_...  (branch_id => branches.id)
#  fk_rails_...  (repository_id => repositories.id)
#
require "rails_helper"

RSpec.describe IssueHistory do
  it_behaves_like "a history model", :quantity
end
