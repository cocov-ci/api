# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateUserPermissionsJob do
  subject(:job) { described_class.new }

  let(:user) { create(:user) }

  it "updates accesses for a given repository" do
    stub_configuration!
    r1 = create(:repository)
    r2 = create(:repository)
    r3 = create(:repository)

    # Currently, `user` has access to r1 and r2
    [r1, r2].each { create(:repository_member, github_member_id: user.github_id, repository: _1) }

    # We will pretend GitHub returns only r1 and r3 as the user's repositories
    org_repos = [r1, r3].map { double(:org_repo, id: _1.github_id) }

    app = double(:app)
    allow(Cocov::GitHub).to receive(:for_user).with(instance_of(User)).and_return(app)
    allow(app).to receive(:organization_repositories)
      .with(@github_organization_name).and_return(org_repos)

    expect(RepositoryMember.count).to eq 2

    # After executing, repositories should go from (r1, r2) to (r1, r3)

    job.perform(user.id)

    expect(RepositoryMember.count).to eq 2
    expect(RepositoryMember.all.pluck(:repository_id).sort).to eq [r1.id, r3.id]
  end
end
