# frozen_string_literal: true

class GitService
  class LocalStorage < BaseStorage
    def initialize
      super
      return if base_path.exist?

      base_path.mkpath
    end

    def base_path
      Pathname.new(Cocov::GIT_SERVICE_LOCAL_STORAGE_PATH)
    end

    def commit_exists?(commit)
      commit_path(commit).exist?
    end

    def download_commit(commit)
      Git.clone(commit, into: commit_path(commit))
    end

    def file_for_commit(commit, path:)
      path = commit_path(commit).join(path)
      file_not_found! path unless Pathname.new(path).exist?
      File.read(path)
    end

    def destroy_repository(repository)
      path = repo_path(repository.name)
      FileUtils.rm_rf path
    end
  end
end
