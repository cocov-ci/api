# frozen_string_literal: true

class GitService
  module Git
    module_function

    def initialize_repository(commit, at:)
      token = Cocov::GitHub.installation_token.token
      repo = commit.repository.name
      org = Cocov::GITHUB_ORGANIZATION_NAME

      [
        "git init",
        "git remote add origin https://x-access-token:#{token}@github.com/#{org}/#{repo}.git",
        "git fetch --depth 1 origin #{commit.sha}",
        "git checkout FETCH_HEAD",
        "rm -rfv .git"
      ].each do |cmd|
        Exec.exec2(cmd, chdir: at)
      end

      true
    end

    def create_compressed_image(commit, at:)
      at = Pathname.new(at).parent
      [
        "tar -cvf #{commit.sha}.tar #{commit.sha}",
        "zstd -T0 #{commit.sha}.tar"
      ].each { Exec.exec2(_1, chdir: at.to_s) }

      shasum = Exec
        .exec("shasum -a256 #{commit.sha}.tar.zst", chdir: at.to_s)
        .split
        .first

      File.write(at.join("#{commit.sha}.tar.zst.shasum").to_s, "sha256:#{shasum}")
    end

    def clone(commit, into:)
      into = Pathname.new(into) unless into.is_a? Pathname
      into.mkpath

      begin
        initialize_repository(commit, at: into)
        create_compressed_image(commit, at: into)
      rescue StandardError => e
        FileUtils.rm_rf into
        FileUtils.rm_rf into.parent.join("#{commit.sha}.tar")
        FileUtils.rm_rf into.parent.join("#{commit.sha}.tar.zst")
        FileUtils.rm_rf into.parent.join("#{commit.sha}.tar.zst.sha256")
        raise e
      end
    end
  end
end
