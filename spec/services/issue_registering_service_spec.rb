# frozen_string_literal: true

require "rails_helper"

RSpec.describe IssueRegisteringService do
  subject(:service) { described_class }

  describe "#validate" do
    ok_request = {
      sha: "",
      source: :a,
      issues: [
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" }
      ]
    }.freeze

    cases = {
      "sha" => ok_request.dup.merge({
        sha: 0
      }),
      "source" => ok_request.dup.merge({
        source: 0
      }),
      "issues" => ok_request.dup.merge({ issues: {} }),
      "issues.0.uid" => ok_request.dup.merge({
        issues: [
          { uid: 0, file: "", line_start: 0, line_end: 0, message: "", kind: "" }
        ]
      }),
      "issues.0.file" => ok_request.dup.merge({
        issues: [
          { uid: "", file: 0, line_start: 0, line_end: 0, message: "", kind: "" }
        ]
      }),
      "issues.0.line_start" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: "", line_end: 0, message: "", kind: "" }
        ]
      }),
      "issues.0.line_end" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: 0, line_end: "", message: "", kind: "" }
        ]
      }),
      "issues.0.message" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: 0, line_end: 0, message: 0, kind: "" }
        ]
      }),
      "issues.0.kind" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: 0 }
        ]
      })
    }.freeze

    cases.each do |name, req|
      it "rejects an invalid #{name}" do
        example = -> { service.validate(req) }
        expect(&example).to raise_error(Cocov::SchemaValidator::ValidationError) do |err|
          expect(err.path.join(".")).to eq name
        end
      end
    end
  end

  describe "#call" do
    let(:repo) { create(:repository) }
    let(:commit) { create(:commit, repository: repo, sha: "65f4e0c879eb83460260637880fb82f188065d11") }
    let(:issue_data) do
      {
        sha: "65f4e0c879eb83460260637880fb82f188065d11",
        source: "cocov/rubocop:v0.1",
        issues: [
          { uid: "rubocop-a", file: "app.rb", line_start: 1, line_end: 2, message: "something is wrong",
            kind: "bug" }
        ]
      }
    end

    before { commit.reset_check_set! }

    it "registers a new issue" do
      service.call(issue_data, repo)

      expect(commit.issues.count).to eq 1
      probl = commit.issues.first
      expect(probl).to be_bug
      expect(probl.uid).to eq "rubocop-a"
      expect(probl.file).to eq "app.rb"
      expect(probl.line_start).to eq 1
      expect(probl.line_end).to eq 2
      expect(probl.message).to eq "something is wrong"
      expect(probl.check_source).to eq "cocov/rubocop"
    end

    it "recycles issues" do
      expect(commit.issues.count).to be_zero

      service.call(issue_data, repo)
      expect(commit.issues.count).to eq 1
      probl = commit.issues.first
      expect(probl).to be_bug
      expect(probl.uid).to eq "rubocop-a"
      expect(probl.file).to eq "app.rb"
      expect(probl.line_start).to eq 1
      expect(probl.line_end).to eq 2
      expect(probl.message).to eq "something is wrong"
      expect(probl.check_source).to eq "cocov/rubocop"

      service.call(issue_data, repo)
      expect(commit.issues.count).to eq 1
      probl = commit.issues.first
      expect(probl).to be_bug
      expect(probl.uid).to eq "rubocop-a"
      expect(probl.file).to eq "app.rb"
      expect(probl.line_start).to eq 1
      expect(probl.line_end).to eq 2
      expect(probl.message).to eq "something is wrong"
      expect(probl.check_source).to eq "cocov/rubocop"
    end

    it "creates issues matching an ignore rule with the correct status" do
      create(:issue_ignore_rule, uid: "rubocop-a", repository: repo, user: create(:user))

      expect(commit.issues.count).to be_zero

      service.call(issue_data, repo)
      expect(commit.issues.count).to eq 1
      expect(commit.issues.first).to be_ignored
    end
  end
end
