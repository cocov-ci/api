# frozen_string_literal: true

class ProcessCommitJob < ApplicationJob
  queue_as :default

  def perform(id)
    commit = Commit.find(id)

    begin
      GitService.clone_commit(commit)
    rescue StandardError => e
      commit.clone_errored!
      commit.create_github_status(:failed, context: "cocov", description: "Could not fetch this commit")
      raise e
    end

    manifest_contents = load_cocov_manifest(commit)
    return if manifest_contents.nil?

    commit.create_github_status(:pending, context: "cocov")

    begin
      manifest = Cocov::Manifest.parse(manifest_contents)
    rescue Cocov::Manifest::InvalidManifestError => e
      commit.create_github_status(:failed, context: "cocov", description: e.message)
      return
    end

    if manifest.checks.empty?
      commit.create_github_status(:success, context: "cocov", description: "Looking good!")
      return
    end

    commit.checks.destroy_all

    job_id = SecureRandom.uuid

    ActiveRecord::Base.transaction do
      manifest.checks.each do |check|
        commit.checks.create!(
          plugin_name: check.plugin.split(":").first,
          status: :waiting
        )
      end

      commit.update! check_job_id: job_id, checks_status: :queued
    end

    Cocov::Redis.instance.rpush("cocov:checks", {
      job_id:,
      org: Cocov::GITHUB_ORGANIZATION_NAME,
      repo: commit.repository.name,
      sha: commit.sha,
      checks: manifest.checks.map(&:plugin),
      git_storage: {
        mode: Cocov::GIT_SERVICE_STORAGE_MODE,
        path: GitService.commit_path(commit)
      }
    }.to_json)

    return unless (email = UserEmail.find_by(email: commit.author_email))

    commit.update! user_id: email.user_id
  end
end
