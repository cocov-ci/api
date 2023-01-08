require 'rails_helper'

RSpec.describe DestroyRepositoryJob, type: :job do
  subject(:job) { described_class.new }

  it "deletes a repository" do
    stub_crypto_key!

    repo = create(:repository)
    branch = create(:branch, repository: repo)
    commit = create(:commit, repository: repo)
    create(:secret, :with_owner, repository: repo, scope: :repository)
    create(:check, commit: commit)
    create(:issue, commit: commit)
    create(:coverage_info, :with_file, commit: commit)

    job.perform(repo.id)
  end
end
