# frozen_string_literal: true

require "rails_helper"

RSpec.describe GitService::Git do
  subject(:git) { described_class }

  describe "#initialize_repository" do
    it "initializes repositories" do
      install_token = double(:installation_token)
      allow(install_token).to receive(:token).and_return("the_token")
      allow(Cocov::GitHub).to receive(:installation_token).and_return(install_token)

      fake_repo = double(:repository)
      allow(fake_repo).to receive(:name).and_return("the_repo")

      fake_commit = double(:commit)
      allow(fake_commit).to receive(:repository).and_return(fake_repo)
      allow(fake_commit).to receive(:sha).and_return "the_sha"
      stub_const("Cocov::GITHUB_ORGANIZATION_NAME", "the_org")

      expected_commands = [
        "git init",
        "git remote add origin https://x-access-token:the_token@github.com/the_org/the_repo.git",
        "git fetch --depth 1 origin the_sha",
        "git checkout FETCH_HEAD",
        "rm -rfv .git"
      ]

      expected_commands.each do |cmd|
        expect(GitService::Exec).to receive(:exec2)
          .with(cmd, chdir: "/tmp")
          .ordered
      end

      git.initialize_repository(fake_commit, at: "/tmp")
    end
  end

  describe "#create_compressed_image" do
    it "creates a compressed image of a commit" do
      commit = double(:commit)
      allow(commit).to receive(:sha).and_return("sha")

      expect(GitService::Exec).to receive(:exec2)
        .with("tar -cvf sha.tar sha", chdir: "/tmp")
        .ordered

      expect(GitService::Exec).to receive(:exec2)
        .with("zstd -T0 sha.tar", chdir: "/tmp")
        .ordered

      expect(GitService::Exec).to receive(:exec)
        .with("shasum -a256 sha.tar.zst", chdir: "/tmp")
        .and_return("foo")
        .ordered

      expect(File).to receive(:write).with("/tmp/sha.tar.zst.shasum", "sha256:foo")

      git.create_compressed_image(commit, at: "/tmp/sha")
    end
  end

  describe "#clone" do
    around do |spec|
      @target_path = Tempfile.new.path
      FileUtils.rm_rf @target_path
      spec.run
      FileUtils.rm_rf @target_path
    end

    it "relays the result of #initialize_repository on success" do
      commit = double(:stub)
      target = Pathname.new(@target_path)
      expect(git).to receive(:initialize_repository)
        .with(commit, at: target)
        .and_return(true)
        .ordered
      expect(git).to receive(:create_compressed_image)
        .with(commit, at: target)
        .and_return(true)
        .ordered

      result = git.clone(commit, into: @target_path)
      expect(target.exist?).to be true
      expect(result).to be true
    end

    it "cleans up and re-raises the error on failure" do
      err = StandardError.new("boom!")
      commit = double(:stub)
      target = Pathname.new(@target_path)
      allow(commit).to receive(:sha).and_return(SecureRandom.uuid)
      expect(git).to receive(:initialize_repository)
        .with(commit, at: target)
        .and_raise(err)

      expect { git.clone(commit, into: @target_path) }.to raise_error(err)
      expect(target.exist?).to be false
    end
  end
end
