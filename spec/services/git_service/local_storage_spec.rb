# frozen_string_literal: true

require "rails_helper"

RSpec.describe GitService::LocalStorage do
  subject(:storage) { described_class.new }

  let(:repo_name) { "foo" }
  let(:repo_sha) { "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33" }
  let(:commit_sha) { "1a31e74545fa2223e5c1a0b79c8ea4cf817422d2" }

  around do |spec|
    @mocked_base_path = Tempfile.new.path
    FileUtils.rm_rf @mocked_base_path
    spec.run
    FileUtils.rm_rf @mocked_base_path
  end

  it "determines whether a commit exists" do
    stub_const("Cocov::GIT_SERVICE_LOCAL_STORAGE_PATH", @mocked_base_path)
    fake_repo = double(:repo)
    allow(fake_repo).to receive(:name).and_return(repo_name)
    fake_commit = double(:commit)
    allow(fake_commit).to receive(:sha).and_return(commit_sha)
    allow(fake_commit).to receive(:repository).and_return(fake_repo)
    expect(storage.commit_exists?(fake_commit)).to be false

    FileUtils.mkdir_p storage.base_path.join(repo_sha, commit_sha)
    expect(storage.commit_exists?(fake_commit)).to be true
  end

  it "obtains a single file for a given commit" do
    stub_const("Cocov::GIT_SERVICE_LOCAL_STORAGE_PATH", @mocked_base_path)
    fake_repo = double(:repo)
    allow(fake_repo).to receive(:name).and_return(repo_name)
    fake_commit = double(:commit)
    allow(fake_commit).to receive(:sha).and_return(commit_sha)
    allow(fake_commit).to receive(:repository).and_return(fake_repo)

    commit_path = storage.base_path.join(repo_sha, commit_sha)
    FileUtils.mkdir_p commit_path
    File.write(commit_path.join("README.md"), "Hello")

    contents = storage.file_for_commit(fake_commit, path: "README.md")
    expect(contents).to eq "Hello"
  end

  it "clones a specific commit" do
    stub_const("Cocov::GIT_SERVICE_LOCAL_STORAGE_PATH", @mocked_base_path)
    fake_repo = double(:repo)
    allow(fake_repo).to receive(:name).and_return(repo_name)
    fake_commit = double(:commit)
    allow(fake_commit).to receive(:sha).and_return(commit_sha)
    allow(fake_commit).to receive(:repository).and_return(fake_repo)

    expect(GitService::Git).to receive(:clone).with(fake_commit, into: storage.commit_path(fake_commit))

    storage.download_commit(fake_commit)
  end
end
