# frozen_string_literal: true

require "rails_helper"

RSpec.describe InitializeRepositoryJob do
  subject(:job) { described_class.new }

  let(:commit_author) do
    double(:commit_author, name: "Paul Appleseed", email: "paul@example.org")
  end

  let(:commit_data) do
    double(:commit_data, author: commit_author, message: "the message")
  end

  let(:meta_commit) { double(:meta_commit, sha: "shasha", commit: commit_data) }

  before do
    stub_configuration!
    bypass_redlock!
  end

  it "stops immediately in case repository has already been initialized" do
    expect(Cocov::GitHub).not_to receive(:app)
    branch = create(:branch, :with_repository, :with_commit)

    job.perform(branch.repository_id)
  end

  it "stops in case branch has no commits" do
    repo = create(:repository)
    github_app = double(:github)
    allow(Cocov::GitHub).to receive(:app).and_return(github_app)
    allow(github_app).to receive(:auto_paginate=).with(false)
    allow(github_app).to receive(:commits)
      .with(repo.full_name, branch: "master", per_page: 1)
      .and_return([])

    # In case the job tries to continue, it will prolly explode trying to access
    # something on a nil object.
    expect { job.perform(repo.id) }.not_to raise_error
  end

  it "creates a commit and attaches it as the head of its branch" do
    repo = create(:repository)
    github_app = double(:github)
    allow(Cocov::GitHub).to receive(:app).and_return(github_app)
    allow(github_app).to receive(:auto_paginate=).with(false)
    allow(github_app).to receive(:commits)
      .with(repo.full_name, branch: "master", per_page: 1)
      .and_return([meta_commit])

    job.perform(repo.id)

    expect(repo.commits.count).to eq 1
    expect(repo.find_default_branch.head_id).to eq repo.commits.first.id
    expect(ProcessCommitJob).to have_been_enqueued.exactly(:once).with(repo.commits.first.id)
  end
end
