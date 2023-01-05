class ChecksRunService < ApplicationService
  def call(commit)
    commit = case commit
    when Commit
      commit
    when String
      Commit.find_by! sha: commit
    when Integer
      Commit.find commit
    else
      commit
    end

    manifest_contents = begin
      GitService.file_for_commit(commit, path: ".cocov.yaml")
    rescue GitService::FileNotFoundError
      nil
    end

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
  end
end
