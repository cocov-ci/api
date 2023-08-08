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

    delegate :commit_path, :destroy_repository, to: :storage

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

    def file_contents(commit, path:)
      cache_key = Digest::SHA1.hexdigest [commit.repository.name, commit.sha, path].compact.join
      file = storage.file_for_commit(commit, path:)

      language = Cocov::Redis.cached_file_language(cache_key) do
        Linguist.detect(Linguist::Blob.new(path, file))&.default_alias || "text"
      end

      [language, file]
    end

    def adjust_range(range)
      return nil unless range

      ([0, range.first - 1].max)..([0, range.last - 1].max)
    end

    def file_for_commit(commit, path:, range: nil)
      raise CommitNotDownloaded unless commit.clone_completed?

      range = adjust_range(range)

      cache_key = Digest::SHA1.hexdigest [commit.repository.name, commit.sha, path, range&.to_a].compact.join
      Cocov::Redis.cached_file(cache_key) do
        language, file = file_contents(commit, path:)
        file = file.lines[range].join if range

        [language, file]
      end
    end
  end
end
