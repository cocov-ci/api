# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateUserPermissionsJob do
  subject(:job) { described_class.new }

  let(:user) { create(:user) }

  it "updates accesses for a given user" do
    stub_configuration!
    r1 = create(:repository, name: 'r1')
    r2 = create(:repository, name: 'r2')
    r3 = create(:repository, name: 'r3')
    r4 = create(:repository, name: 'r4')

    user_permission = double(:user_permission, pull: true, push: true, admin: false, maintain: false)

    # Currently, `user` has access to r1 and r2
    [r1, r2].each { create(:repository_member, github_member_id: user.github_id, repository: _1) }

    # User also has access to "R5", but Cocov doesn't know that repo.
    # We will pretend GitHub returns only r1 and r3 as the user's repositories,
    # and drops the user's administrative permissions on r4
    org_repos = [r1, r3].map { double(:org_repo, id: _1.github_id, permissions: user_permission) }
    org_repos << double(:org_repo, id: r4.github_id, permissions: user_permission)
    org_repos << double(:org_repo, id: r4.github_id + 1, permissions: user_permission)

    app = double(:app)
    allow(Cocov::GitHub).to receive(:for_user).with(instance_of(User)).and_return(app)
    allow(app).to receive(:organization_repositories)
      .with(@github_organization_name).and_return(org_repos)

    expect(RepositoryMember.count).to eq 2

    # After executing, repositories should go from (r1, r2, r4) to (r1, r3, r4)
    # and r4 permissions must be 'user'

    job.perform(user.id)

    expect(RepositoryMember.count).to eq 3
    expect(RepositoryMember.all.pluck(:repository_id).sort).to eq [r1.id, r3.id, r4.id]
    expect(RepositoryMember.find_by(github_member_id: user.github_id, repository_id: r4.id).level).to eq "user"
  end
end
