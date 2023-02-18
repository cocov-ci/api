# frozen_string_literal: true

# == Schema Information
#
# Table name: check_sets
#
#  id         :bigint           not null, primary key
#  commit_id  :bigint           not null
#  status     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_check_sets_on_commit_id  (commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
require "rails_helper"

RSpec.describe CheckSet do
  subject(:set) { build(:check_set, :with_commit) }

  it_behaves_like "a validated model", %i[
    commit_id
  ]
end
