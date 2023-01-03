# frozen_string_literal: true

class ManifestService < ApplicationService
  def self.manifest_for_commit(commit)
    commit = case commit
             when Numeric
               Commit.find(id)
             when String
               Commit.find_by!(sha: commit)
             when Commit
               commit
             else
               throw ArgumentError, "commit must be a sha, ID, or Commit instance"
             end

    GitService.clone_commit(commit)

    manifest_data = begin
      GitService.file_for_commit(commit, path: ".cocov.yaml")
    rescue GitService::FileNotFoundError
      nil
    end
    return nil unless manifest_data

    Cocov::Manifest.parse(manifest_data)
  end
end
