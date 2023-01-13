# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateRepoPermissionsJob do
  subject(:job) { described_class.new }

  let(:repo) { create(:repository) }

  it "updates accesses for a given repository" do
    collabs = (1..3).map do |id|
      RepositoryMember.create! github_member_id: id, repository: repo if id != 3
      double(:collab, id:)
    end

    collabs.delete_at 1

    # collab 2 is gone from remote
    # collab 3 was added to remote, but does not exist in local.

    app = double(:app)
    allow(Cocov::GitHub).to receive(:app).and_return(app)
    allow(app).to receive(:collaborators).with(repo.github_id).and_return(collabs)

    expect(collabs.length).to eq 2
    expect(RepositoryMember.count).to eq 2

    # After executing, members should go from (1, 2) to (1, 3)

    job.perform(repo.id)

    expect(RepositoryMember.count).to eq 2
    expect(RepositoryMember.all.pluck(:github_member_id).sort).to eq [1, 3]
  end
end
