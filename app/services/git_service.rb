# frozen_string_literal: true

class GitService < ApplicationService
  class CommitNotDownloaded < StandardError; end
  class FileNotFoundError < StandardError; end

  class << self
    def storage
      @storage ||= case Cocov::GIT_SERVICE_STORAGE_MODE
                   when :local
                     LocalStorage.new
                   when :s3
                     S3Storage.new
                   end
    end

    delegate :commit_path, to: :storage

    def clone_commit(commit)
      commit.locking(timeout: 5.minutes) do
        return if commit.reload.clone_completed?

        commit.clone_in_progress!
        storage.download_commit(commit)
        commit.clone_completed!
      rescue StandardError => e
        commit.clone_errored!
        raise e
      end
    end

    def file_for_commit(commit, path:, range: nil)
      raise CommitNotDownloaded unless commit.clone_completed?

      cache_key = Digest::SHA1.hexdigest [commit.repository.name, commit.sha, path, range].compact.join
      Cocov::Redis.cached_file(cache_key) do
        file = storage.file_for_commit(commit, path:)
        file = file.lines[range].join if range
        file
      end
    end
  end
end
