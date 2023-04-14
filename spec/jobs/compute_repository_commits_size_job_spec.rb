require 'rails_helper'

RSpec.describe ComputeRepositoryCommitsSizeJob, type: :job do
  subject(:job) { described_class.new }

  it "updates a repository commit size" do
    r = create(:repository)
    expect(r.commits_size).to be_zero
    c = create(:commit, repository: r, clone_size: 10)
    subject.perform(r.id)
    expect(r.reload.commits_size).to eq 10
  end

end
