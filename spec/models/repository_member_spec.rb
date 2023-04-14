# frozen_string_literal: true

# == Schema Information
#
# Table name: repository_members
#
#  id               :bigint           not null, primary key
#  repository_id    :bigint           not null
#  github_member_id :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  level            :integer          not null
#
# Indexes
#
#  index_repository_members_on_github_member_id                    (github_member_id)
#  index_repository_members_on_repository_id                       (repository_id)
#  index_repository_members_on_repository_id_and_github_member_id  (repository_id,github_member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
require "rails_helper"

RSpec.describe RepositoryMember do
  subject(:member) do
    repo = create(:repository)
    build(:repository_member, repository: repo)
  end

  it_behaves_like "a validated model", %i[
    repository
    github_member_id
    level
  ]

  it "does not allow duplicated members" do
    expect(member).to be_valid
    expect { member.save! }.not_to raise_error

    other_member = described_class.new(github_member_id: member.github_member_id, repository: member.repository)
    expect(other_member).not_to be_valid
  end

  it "counts members per repository level" do
    u1 = create(:user)
    u2 = create(:user)

    r1 = create(:repository)
    r2 = create(:repository)
    r3 = create(:repository)

    grant(u1, access_to: r1, as: :user)
    grant(u2, access_to: r1, as: :maintainer)
    grant(u2, access_to: r2, as: :admin)
    grant(u2, access_to: r3, as: :admin)

    # u1 has 1 user, nothing else
    # u2 has 1 maintainer, 2 admin

    result = described_class.count_users_permissions(users: [u1, u2])
    expect(result[u1.id]["user"]).to eq 1
    expect(result[u1.id]["maintainer"]).to eq 0
    expect(result[u1.id]["admin"]).to eq 0
    expect(result[u2.id]["user"]).to eq 0
    expect(result[u2.id]["maintainer"]).to eq 1
    expect(result[u2.id]["admin"]).to eq 2
  end
end
