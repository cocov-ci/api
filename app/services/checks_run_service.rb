# frozen_string_literal: true

class ChecksRunService < ApplicationService
  def prepare_mounts(check)
    return if check.mounts.blank?

    mounts = []

    check.mounts.each do |m|
      # Strip non-secret data, as we don't support any other mount type.
      next unless m.source.start_with? "secrets:"

      name = m.source.gsub(/^secrets:/, "")
      secret = @commit.repository.find_secret(name)
      raise Cocov::Manifest::InvalidManifestError, "Unknown secret `#{name}'" if secret.nil?

      mounts << {
        kind: :secret,
        authorization: secret.generate_authorization,
        target: m.destination
      }
    end

    mounts
  end

  def call(commit)
    commit = case commit
             when String
               Commit.find_by! sha: commit
             when Integer
               Commit.find commit
             else
               commit
             end
    @commit = commit
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
      # TODO: URL?
      commit.create_github_status(:failed, context: "cocov", description: e.message)
      return
    end

    if manifest.checks.empty?
      commit.create_github_status(:success, context: "cocov", description: "Looking good!")
      return
    end

    checks = manifest.checks.map do |check|
      { plugin: check.plugin, envs: check.envs }.tap do |data|
        data[:mounts] = prepare_mounts(check)
      end
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
      checks:,
      git_storage: {
        mode: Cocov::GIT_SERVICE_STORAGE_MODE,
        path: GitService.commit_path(commit)
      }
    }.to_json)
  end
end
