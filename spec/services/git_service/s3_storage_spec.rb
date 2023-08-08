# frozen_string_literal: true

require "rails_helper"

RSpec.describe GitService::S3Storage do
  subject(:storage) do
    stub_s3!
    stub_const("Cocov::GIT_SERVICE_S3_STORAGE_BUCKET_NAME", "bubucket")
    described_class.new
  end

  let(:repo_name) { "foo" }
  let(:repo_sha) { "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33" }
  let(:commit_sha) { "1a31e74545fa2223e5c1a0b79c8ea4cf817422d2" }

  before { storage } # ensure @s3 is available...

  it "determines whether a commit exists" do
    @s3.client.stub_responses(:head_object,
      { status_code: 200, headers: {}, body: "" },
      { status_code: 404, headers: {}, body: "" })

    repo = create(:repository, name: repo_name)
    commit = create(:commit, repository: repo, sha: commit_sha)

    expect(storage.commit_exists?(commit)).to be true
    expect(storage.commit_exists?(commit)).to be false
  end

  it "obtains a single file for a given commit" do
    @s3.client.stub_responses(:get_object,
      { body: "Hello!" },
      "NoSuchKey")

    repo = create(:repository, name: repo_name)
    commit = create(:commit, repository: repo, sha: commit_sha)

    expect(storage.file_for_commit(commit, path: "bla")).to eq "Hello!"

    expect { storage.file_for_commit(commit, path: "bla") }
      .to raise_error GitService::FileNotFoundError
  end

  it "clones a specific commit" do
    fake_repo = double(:repo)
    allow(fake_repo).to receive(:name).and_return(repo_name)
    fake_commit = double(:commit)
    allow(fake_commit).to receive_messages(sha: commit_sha, repository: fake_repo)

    expect(GitService::Git).to receive(:clone).with(fake_commit, into: anything)

    cmdline = "aws s3 cp --recursive --only-show-errors --follow-symlinks . s3://bubucket/#{repo_sha}/"
    expect(GitService::Exec).to receive(:exec).with(cmdline, chdir: anything, env: anything)

    storage.download_commit(fake_commit)
  end
end
