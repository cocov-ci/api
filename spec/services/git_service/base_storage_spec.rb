# frozen_string_literal: true

require "rails_helper"

RSpec.describe GitService::BaseStorage do
  subject(:storage) { described_class.new }

  it "raises NotImplementedError for #download_commit" do
    expect { storage.download_commit(:any) }.to raise_error(NotImplementedError)
  end

  it "raises NotImplementedError for #file_for_commit" do
    expect { storage.file_for_commit(:any, path: :any) }.to raise_error(NotImplementedError)
  end

  it "raises NotImplementedError for #base_path" do
    expect { storage.base_path }.to raise_error(NotImplementedError)
  end

  describe "path making" do
    let(:repo_name) { "foo" }
    let(:repo_sha) { "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33" }
    let(:commit_sha) { "1a31e74545fa2223e5c1a0b79c8ea4cf817422d2" }

    context "when base_path is a Pathname" do
      before do
        allow(storage).to receive(:base_path).and_return(Pathname.new("/tmp"))
      end

      it "returns a #repo_path" do
        expect(storage.repo_path(repo_name)).to be_a Pathname
        expect(storage.repo_path(repo_name).to_s).to eq "/tmp/#{repo_sha}"
      end

      it "returns a commit_path" do
        fake_repo = double(:repo)
        allow(fake_repo).to receive(:name).and_return(repo_name)
        fake_commit = double(:commit)
        allow(fake_commit).to receive(:sha).and_return(commit_sha)
        allow(fake_commit).to receive(:repository).and_return(fake_repo)

        expect(storage.commit_path(fake_commit)).to be_a Pathname
        expect(storage.commit_path(fake_commit).to_s).to eq "/tmp/#{repo_sha}/#{commit_sha}"
      end
    end

    context "when base_path is a String" do
      before do
        allow(storage).to receive(:base_path).and_return("/tmp")
      end

      it "returns a #repo_path" do
        expect(storage.repo_path(repo_name)).to be_a String
        expect(storage.repo_path(repo_name)).to eq "/tmp/#{repo_sha}"
      end

      it "returns a commit_path" do
        fake_repo = double(:repo)
        allow(fake_repo).to receive(:name).and_return(repo_name)
        fake_commit = double(:commit)
        allow(fake_commit).to receive(:sha).and_return(commit_sha)
        allow(fake_commit).to receive(:repository).and_return(fake_repo)

        expect(storage.commit_path(fake_commit)).to be_a String
        expect(storage.commit_path(fake_commit)).to eq "/tmp/#{repo_sha}/#{commit_sha}"
      end
    end
  end
end
