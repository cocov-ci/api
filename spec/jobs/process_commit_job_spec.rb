# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessCommitJob do
  subject(:job) { described_class.new }

  before do
    stub_configuration!
    allow(Commit).to receive(:find).with(commit.id).and_return(commit)
  end

  let(:commit) { create(:commit, :with_repository) }

  it "stops processing in case fetch fails" do
    expect(GitService).to receive(:clone_commit)
      .with(commit)
      .and_raise(StandardError.new("boom!"))

    expect(commit).to receive(:create_github_status)
      .with(:failure, context: "cocov", description: "Could not fetch this commit")

    expect(ChecksRunService).not_to receive(:call)

    expect { job.perform(commit.id) }.to raise_error(StandardError)
      .with_message("boom!")
  end

  it "stops processing commits without manifests" do
    expect(GitService).to receive(:clone_commit).with(commit)
    expect(GitService).to receive(:file_for_commit)
      .with(commit, path: ".cocov.yaml")
      .and_raise(GitService::FileNotFoundError)
    expect(commit).not_to receive(:create_github_status)

    job.perform(commit.id)
  end

  it "updates statuses for commits with invalid manifests" do
    expect(GitService).to receive(:clone_commit).with(commit)
    expect(GitService).to receive(:file_for_commit)
      .with(commit, path: ".cocov.yaml")
      .and_return("lolsies, this is an invalid manifest!")
    expect(commit).to receive(:create_github_status).with(:pending, context: "cocov").ordered
    expect(commit).to receive(:create_github_status)
      .with(:failure, context: "cocov", description: "Invalid manifest: Root should be a mapping")
      .ordered

    job.perform(commit.id)
  end

  it "returns a successful status for manifests without checks" do
    expect(GitService).to receive(:clone_commit).with(commit)
    fake_manifest = double(:manifest)
    allow(fake_manifest).to receive(:checks).and_return([])

    expect(GitService).to receive(:file_for_commit)
      .with(commit, path: ".cocov.yaml")
      .and_return(:some_contents)
    expect(Cocov::Manifest).to receive(:parse)
      .with(:some_contents)
      .and_return(fake_manifest)

    expect(commit).to receive(:create_github_status).with(:pending, context: "cocov").ordered
    expect(commit).to receive(:create_github_status)
      .with(:success, context: "cocov", description: "Looking good!")
      .ordered

    expect(commit).not_to receive(:checks)

    job.perform(commit.id)

    expect(commit.reload.checks_status).to eq "not_configured"
  end

  it "creates checks and enqueues a new check job" do
    mock_redis!
    stub_crypto_key!

    expect(GitService).to receive(:clone_commit).with(commit)
    fake_manifest = double(:manifest)
    allow(fake_manifest).to receive(:checks).and_return([])

    expect(GitService).to receive(:file_for_commit)
      .with(commit, path: ".cocov.yaml")
      .and_return(fixture_file("manifests/v0.1alpha/complete.yaml"))

    expect(commit).to receive(:create_github_status).with(:pending, context: "cocov").ordered

    expect(commit.checks.count).to be_zero
    expect(@redis.llen("cocov:checks")).to be_zero
    allow(SecureRandom).to receive(:uuid).and_return("this-is-an-uuid")
    allow(SecureRandom).to receive(:hex).with(anything).and_return("23035196471c5ab5b3b5b03ee9bf494215defa61457311d6")

    sec = create(:secret, :with_owner, name: "FOO")

    u = create(:user)
    u.emails.create! email: commit.author_email

    job.perform(commit.id)

    expect(commit.checks.count).to eq 2
    expect(commit.checks.where(plugin_name: "cocov-ci/rubocop")).to be_exist
    expect(commit.checks.where(plugin_name: "cocov-ci/brakeman")).to be_exist

    expect(@redis.llen("cocov:checks")).to eq 1

    op = JSON.parse(@redis.lrange("cocov:checks", 0, 0).first)
    expect(op).to eq({
      "job_id" => "this-is-an-uuid",
      "org" => @github_organization_name,
      "repo" => commit.repository.name,
      "repo_id" => commit.repository_id,
      "sha" => commit.sha,
      "checks" => [
        {
          "plugin" => "cocov-ci/rubocop:v0.1",
          "envs" => { "TEST" => "true" },
          "mounts" => nil
        },
        {
          "plugin" => "cocov-ci/brakeman:v0.1",
          "envs" => nil,
          "mounts" => [
            {
              "authorization" => "csa_23035196471c5ab5b3b5b03ee9bf494215defa61457311d6",
              "kind" => "secret",
              "target" => "~/test"
            }
          ]
        }
      ],
      "git_storage" => {
        "mode" => "local",
        "path" => GitService.storage.commit_path(commit).to_s
      }
    })

    expect(Secret.from_authorization("csa_23035196471c5ab5b3b5b03ee9bf494215defa61457311d6").id).to eq sec.id

    expect(commit.reload.user_id).to eq u.id
  end
end
