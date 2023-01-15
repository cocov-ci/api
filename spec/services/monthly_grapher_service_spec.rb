# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthlyGrapherService do
  subject { described_class }

  let(:repo) { create(:repository) }
  let(:commit) { create(:commit, repository: repo) }
  let(:branch) { create(:branch, repository: repo, head: commit) }

  before do
    mock_redis!
    branch # initialise branch, commit, repo
    IssueHistory.register_history!(commit, 10)
    CoverageHistory.register_history!(commit, 10)
  end

  describe "parameter repository" do
    it "accepts a Repository instance" do
      result = described_class.call(repo, :issues)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end

    it "rejects anything else" do
      expect { described_class.call(:what, :issues) }.to raise_error(ArgumentError)
    end
  end

  describe "parameter kind" do
    it "accepts :issues" do
      result = described_class.call(repo, :issues)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end

    it "accepts :coverage" do
      result = described_class.call(repo, :coverage)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end

    it "rejects anything else" do
      expect { described_class.call(repo, :what) }.to raise_error(ArgumentError)
    end
  end

  describe "parameter branch" do
    it "accepts nil" do
      result = described_class.call(repo, :coverage, branch: nil)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end

    it "accepts a Branch instance" do
      result = described_class.call(repo, :coverage, branch:)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end

    it "accepts a branch id" do
      result = described_class.call(repo, :coverage, branch: branch.id)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end

    it "accepts a branch name" do
      result = described_class.call(repo, :coverage, branch: branch.name)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end

    it "rejects anything else" do
      expect { described_class.call(repo, :coverage, branch: :what) }.to raise_error(ArgumentError)
    end
  end

  describe "caching" do
    it "correctly writes and reads from cache" do
      expect(@cache.keys).to be_empty

      result = described_class.call(repo, :coverage, branch: branch.name)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10

      expect(@cache.keys).not_to be_empty

      result = described_class.call(repo, :coverage, branch: branch.name)
      expect(result.length).to be >= 30
      expect(result.last).to eq 10
    end
  end
end
