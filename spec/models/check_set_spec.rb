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
require "rails_helper"

RSpec.describe CheckSet do
  subject(:set) { build(:check_set, :with_commit) }

  it_behaves_like "a validated model", %i[
    commit_id
  ]

  it "refuses to wrap up if a check is still running" do
    check = create(:check, :running, :with_commit)
    set = check.check_set

    expect { set.wrap_up! }.to raise_error(CheckSet::InconsistentCheckStatusError)
  end
end
