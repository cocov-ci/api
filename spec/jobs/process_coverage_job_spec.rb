# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessCoverageJob do
  subject(:job) { described_class.new }

  before { stub_configuration! }

  let(:commit) { create(:commit, :with_repository) }
  let(:payload) { JSON.parse(fixture_file("coverage_data.json"))["data"].to_json }

  it "creates coverage data" do
    allow(ManifestService).to receive(:manifest_for_commit).with(anything).and_return(nil)
    app = double(:app)
    allow(Cocov::GitHub).to receive(:app).and_return(app)
    allow(app).to receive(:create_status)
      .with(
        "#{@github_organization_name}/#{commit.repository.name}",
        commit.sha,
        "success",
        context: "cocov/coverage",
        description: "94.29% covered",
        target_url: "#{@ui_base_url}/repos/#{commit.repository.name}/commits/#{commit.sha}/coverage"
      )

    job.perform(commit.repository_id, commit.sha, payload)

    cov = commit.coverage
    cov.reload
    expect(cov.lines_total).to eq 1104
    expect(cov.lines_covered).to eq 1041
    expect(cov.percent_covered).to be_within(0.01).of(94.29)
  end

  it "creates conditional statuses (success)" do
    manifest = double(:manifest)
    cov = Cocov::Manifest::V01Alpha::Coverage.new(min_percent: 20)
    allow(manifest).to receive(:coverage).and_return(cov)
    allow(ManifestService).to receive(:manifest_for_commit).with(anything).and_return(manifest)

    app = double(:app)
    allow(Cocov::GitHub).to receive(:app).and_return(app)
    expect(app).to receive(:create_status)
      .with(
        "#{@github_organization_name}/#{commit.repository.name}",
        commit.sha,
        "success",
        context: "cocov/coverage",
        description: "94.29% covered",
        target_url: "#{@ui_base_url}/repos/#{commit.repository.name}/commits/#{commit.sha}/coverage"
      )

    job.perform(commit.repository_id, commit.sha, payload)
  end

  it "creates conditional statuses (failure)" do
    manifest = double(:manifest)
    cov = Cocov::Manifest::V01Alpha::Coverage.new(min_percent: 100)
    allow(manifest).to receive(:coverage).and_return(cov)
    allow(ManifestService).to receive(:manifest_for_commit).with(anything).and_return(manifest)

    app = double(:app)
    allow(Cocov::GitHub).to receive(:app).and_return(app)
    expect(app).to receive(:create_status)
      .with(
        "#{@github_organization_name}/#{commit.repository.name}",
        commit.sha,
        "failure",
        context: "cocov/coverage",
        description: "94.29% covered (at least 100% is required)",
        target_url: "#{@ui_base_url}/repos/#{commit.repository.name}/commits/#{commit.sha}/coverage"
      )

    job.perform(commit.repository_id, commit.sha, payload)
  end
end
