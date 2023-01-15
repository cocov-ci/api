# frozen_string_literal: true

require "rails_helper"

RSpec.describe DestroyRepositoryJob do
  subject(:job) { described_class.new }

  it "deletes a repository" do
    stub_crypto_key!

    repo = create(:repository)
    commit = create(:commit, repository: repo)
    branch = create(:branch, repository: repo, head: commit)

    create(:secret, :with_owner, repository: repo, scope: :repository)
    create(:check, commit:)
    create(:issue, commit:)
    create(:issue_history, repository: repo, branch:)
    create(:coverage_history, repository: repo, branch:)
    create(:coverage_info, :with_file, commit:)

    job.perform(repo.id)

    expect(Repository.exists?(id: repo.id)).to be false
  end
end
