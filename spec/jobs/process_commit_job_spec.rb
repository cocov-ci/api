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
      .with(:error,
        context: "cocov",
        description: "Could not fetch this commit",
        url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks")

    expect(ChecksRunService).not_to receive(:call)

    expect { job.perform(commit.id) }.to raise_error(StandardError)
      .with_message("boom!")
  end

  it "stops processing commits without manifests" do
    allow(GitService).to receive(:clone_commit) { expect(_1.id).to eq commit.id }
    expect(GitService).to receive(:file_for_commit)
      .with(commit, path: ".cocov.yaml")
      .and_raise(GitService::FileNotFoundError)
    expect(commit).not_to receive(:create_github_status)

    job.perform(commit.id)
  end

  it "updates statuses for commits with invalid manifests" do
    allow(GitService).to receive(:clone_commit) { expect(_1.id).to eq commit.id }
    expect(GitService).to receive(:file_for_commit)
      .with(commit, path: ".cocov.yaml")
      .and_return(["yaml", "lolsies, this is an invalid manifest!"])
    expect(commit).to receive(:create_github_status)
      .with(:error,
        context: "cocov",
        description: "Invalid manifest: Root should be a mapping",
        url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks")
      .ordered

    job.perform(commit.id)

    expect(commit.check_set.error_kind).to eq "manifest_root_must_be_mapping"
    expect(commit.check_set.error_extra).to be_nil
  end

  it "updates statuses for commits with invalid manifests (unknown secret)" do
    allow(GitService).to receive(:clone_commit) { expect(_1.id).to eq commit.id }
    expect(GitService).to receive(:file_for_commit)
      .with(commit, path: ".cocov.yaml")
      .and_return(["yaml", fixture_file("manifests/v0.1alpha/complete.yaml")])
    expect(commit).to receive(:create_github_status)
      .with(:pending,
        context: "cocov",
        description: "Checks are running...",
        url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks")
      .ordered
    expect(commit).to receive(:create_github_status)
      .with(:error,
        context: "cocov",
        description: "Failure: Unknown secret",
        url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks")
      .ordered

    job.perform(commit.id)

    expect(commit.check_set.error_kind).to eq "manifest_unknown_secret"
    expect(commit.check_set.error_extra).to eq "Unknown secret `FOO'"
  end

  it "returns a successful status for manifests without checks" do
    allow(GitService).to receive(:clone_commit) { expect(_1.id).to eq commit.id }
    fake_manifest = double(:manifest)
    allow(fake_manifest).to receive(:checks).and_return([])

    expect(GitService).to receive(:file_for_commit)
      .with(-> { _1.id == commit.id }, path: ".cocov.yaml")
      .and_return(["yaml", :some_contents])
    expect(Cocov::Manifest).to receive(:parse)
      .with(:some_contents)
      .and_return(fake_manifest)

    expect(commit).to receive(:create_github_status)
      .with(:success,
        context: "cocov",
        description: "Looking good!",
        url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks")
      .ordered

    expect(commit).not_to receive(:checks)

    job.perform(commit.id)

    expect(commit.reload.checks_status).to eq "not_configured"
  end

  it "creates checks and enqueues a new check job" do
    mock_redis!
    stub_crypto_key!

    allow(GitService).to receive(:clone_commit) { expect(_1.id).to eq commit.id }
    expect(GitService).to receive(:file_for_commit)
      .with(-> { _1.id == commit.id }, path: ".cocov.yaml")
      .and_return(["yaml", fixture_file("manifests/v0.1alpha/complete.yaml")])

    expect(commit).to receive(:create_github_status)
      .with(:pending,
        context: "cocov",
        description: "Checks are running...",
        url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks")
      .ordered

    expect(commit.checks.count).to be_zero
    expect(@redis.llen("cocov:checks")).to be_zero
    allow(SecureRandom).to receive(:uuid).and_return("this-is-an-uuid")
    allow(SecureRandom).to receive(:hex).with(anything).and_return("23035196471c5ab5b3b5b03ee9bf494215defa61457311d6")

    sec = create(:secret, :with_owner, name: "FOO")

    u = create(:user)
    u.emails.create! email: commit.author_email

    job.perform(commit.id)

    expect(commit.checks.count).to eq 2
    expect(commit.checks.where(plugin_name: "cocov/rubocop")).to be_exist
    expect(commit.checks.where(plugin_name: "cocov/brakeman")).to be_exist
    expect(commit.check_set).to be_queued

    expect(@redis.llen("cocov:checks")).to eq 1

    op = JSON.parse(@redis.lrange("cocov:checks", 0, 0).first)
    expect(op).to eq({
      "check_set_id" => commit.check_set.id,
      "job_id" => "this-is-an-uuid",
      "org" => @github_organization_name,
      "repo" => commit.repository.name,
      "repo_id" => commit.repository_id,
      "sha" => commit.sha,
      "checks" => [
        {
          "plugin" => "cocov/rubocop:v0.1",
          "envs" => { "TEST" => "true" },
          "mounts" => nil
        },
        {
          "plugin" => "cocov/brakeman:v0.1",
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
