# frozen_string_literal: true

# == Schema Information
#
# Table name: branches
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  name          :citext           not null
#  issues        :integer
#  coverage      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  head_id       :bigint
#
# Indexes
#
#  index_branches_on_head_id                 (head_id)
#  index_branches_on_repository_id           (repository_id)
#  index_branches_on_repository_id_and_name  (repository_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (head_id => commits.id)
#  fk_rails_...  (repository_id => repositories.id)
#
require "rails_helper"

RSpec.describe Branch do
  subject(:branch) { build(:branch, :with_repository) }

  it_behaves_like "a validated model", %i[
    name
    repository
  ]

  it "does not allow duplicated branches" do
    expect(branch).to be_valid
    expect { branch.save! }.not_to raise_error

    other_branch = described_class.new(name: "master", repository: branch.repository)
    expect(other_branch).not_to be_valid
  end
end
