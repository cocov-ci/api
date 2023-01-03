# frozen_string_literal: true

require "rails_helper"

RSpec.describe GitService do
  subject(:service) { described_class }

  describe "#storage" do
    before do
      described_class.instance_variable_set(:@storage, nil)
    end

    it "returns the local storage handler based on configuration" do
      stub_const("Cocov::GIT_SERVICE_STORAGE_MODE", :local)
      expect(described_class.storage).to be_a GitService::LocalStorage
    end

    it "returns the s3 storage handler based on configuration" do
      stub_s3!
      stub_const("Cocov::GIT_SERVICE_STORAGE_MODE", :s3)
      expect(described_class.storage).to be_a GitService::S3Storage
    end
  end

  describe "#file_for_commit" do
    it "refuses to get file for non-downloaded commit" do
      commit = create(:commit, :with_repository)
      expect { service.file_for_commit(commit, path: "foo/bar/baz") }.to raise_error(GitService::CommitNotDownloaded)
    end

    it "returns cached data without touching storage" do
      mock_redis!
      expect(service).not_to receive(:storage)

      commit = create(:commit, :with_repository)
      commit.clone_completed!
      expected_key = Digest::SHA1.hexdigest [commit.repository.name, commit.sha, "foo/bar"].compact.join
      @cache.set(expected_key, "contents")

      expect(service.file_for_commit(commit, path: "foo/bar")).to eq "contents"
    end

    it "gets data from storage and caches it" do
      mock_redis!
      commit = create(:commit, :with_repository)
      commit.clone_completed!

      storage = double(:storage)
      allow(service).to receive(:storage).and_return(storage)
      allow(storage).to receive(:file_for_commit).with(commit, path: "foo/bar").and_return("contents")
      expected_key = Digest::SHA1.hexdigest [commit.repository.name, commit.sha, "foo/bar"].compact.join

      expect(@cache.get(expected_key)).to be_nil
      expect(service.file_for_commit(commit, path: "foo/bar")).to eq "contents"
      expect(@cache.get(expected_key)).to eq "contents"
    end
  end

  describe "#clone_commit" do
    let(:commit) { create(:commit, :with_repository) }

    it "stops processing in case the commit has already been clonned" do
      expect(commit).to receive(:locking).with(timeout: 5.minutes) do |&block|
        Commit.find(commit.id).clone_completed!

        block.call
      end

      expect(commit).not_to receive(:clone_in_progress!)

      service.clone_commit(commit)
    end

    it "updates commit accordingly on success" do
      expect(commit).to receive(:locking).with(timeout: 5.minutes).and_yield
      expect(commit).not_to receive(:clone_errored!)

      expect(commit).to receive(:clone_in_progress!).ordered
      expect(service.storage).to receive(:download_commit).with(commit).ordered
      expect(commit).to receive(:clone_completed!).ordered
      service.clone_commit(commit)
    end

    it "updates commit accordingly on error" do
      expect(commit).to receive(:locking).with(timeout: 5.minutes).and_yield
      expect(commit).not_to receive(:clone_completed!)

      expect(commit).to receive(:clone_in_progress!).ordered
      expect(service.storage).to receive(:download_commit)
        .with(commit)
        .ordered
        .and_raise(StandardError.new("boom!"))
      expect(commit).to receive(:clone_errored!).ordered

      expect { service.clone_commit(commit) }.to raise_error(StandardError)
        .with_message("boom!")
    end
  end
end
