# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateRepoPermissionsJob do
  subject(:job) { described_class.new }

  let(:repo) { create(:repository) }

  it "updates accesses for a given repository" do
    user_perm = double(:permission, push: true, pull: true, admin: false, maintain: false)

    collabs = (1..4).map do |id|
      if id == 4
        RepositoryMember.create! github_member_id: id, repository: repo, level: :admin
      elsif id != 3
        RepositoryMember.create! github_member_id: id, repository: repo, level: :user
      end
      double(:collab, id:, permissions: user_perm)
    end

    collabs.delete_at 1

    # collab 2 is gone from remote
    # collab 3 was added to remote, but does not exist in local.
    # collab 4 goes from admin to user

    app = double(:app)
    allow(Cocov::GitHub).to receive(:app).and_return(app)
    allow(app).to receive(:collaborators).with(repo.github_id).and_return(collabs)

    expect(collabs.length).to eq 3
    expect(RepositoryMember.count).to eq 3
    expect(RepositoryMember.find_by(github_member_id: 4).level).to eq "admin"

    # After executing, members should go from (1, 2, 4) to (1, 3, 4)
    # and member 4's permission must be `user`

    job.perform(repo.id)

    expect(RepositoryMember.count).to eq 3
    expect(RepositoryMember.all.pluck(:github_member_id).sort).to eq [1, 3, 4]
    expect(RepositoryMember.find_by(github_member_id: 4).level).to eq "user"
  end
end
