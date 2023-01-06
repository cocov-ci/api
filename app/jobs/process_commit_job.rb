# frozen_string_literal: true

class ProcessCommitJob < ApplicationJob
  queue_as :default

  def perform(id)
    commit = Commit.find(id)

    begin
      GitService.clone_commit(commit)
    rescue StandardError => e
      commit.clone_errored!
      commit.create_github_status(:failure, context: "cocov", description: "Could not fetch this commit")
      raise e
    end

    ChecksRunService.call(commit)

    commit.adjust_associated_user!
  end
end
