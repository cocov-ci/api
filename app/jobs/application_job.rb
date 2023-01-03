# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def load_cocov_manifest(commit)
    GitService.file_for_commit(commit, path: ".cocov.yaml")
  rescue GitService::FileNotFoundError
    nil
  end
end
