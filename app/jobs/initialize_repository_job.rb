# frozen_string_literal: true

class InitializeRepositoryJob < ApplicationJob
  queue_as :default

  def perform(repo_id)
    repo = Repository.find(repo_id)
    return unless repo.find_default_branch&.head.nil?

    app = Cocov::GitHub.app
    app.auto_paginate = false
    commit_meta = app
      .commits(repo.full_name, branch: repo.default_branch, per_page: 1)
      &.first
    return if commit_meta.nil?

    sha = commit_meta.sha
    commit = Cocov::Redis.lock("commit:#{repo.id}:#{sha}", 1.minute) do
      commit = repo.commits.find_by(sha:)
      next if commit

      Commit.create!(
        repository: repo,
        sha:,
        message: commit_meta.commit.message,
        author_name: commit_meta.commit.author.name,
        author_email: commit_meta.commit.author.email
      )
    end

    branch = repo.branches.find_or_initialize_by(name: repo.default_branch)
    branch.head_id = commit.id
    branch.save!

    ProcessCommitJob.perform_later(commit.id)
  end
end
