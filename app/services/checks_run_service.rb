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
      Commit.includes(:repository).find_by! sha: commit
    when Integer
      Commit.includes(:repository).find commit
    else
      commit
    end

    @commit = commit

    commit.reset_check_set!

    begin
      manifest = ManifestService.manifest_for_commit(@commit)
    rescue Cocov::Manifest::InvalidManifestError => e
      commit.create_github_status(:failure,
        context: "cocov",
        description: e.message,
        url: commit.checks_url)
      return
    end

    if manifest.nil?
      commit.check_set.not_configured!
      return
    end

    if manifest.checks.empty?
      commit.check_set.not_configured!
      commit.create_github_status(:success, context: "cocov", description: "Looking good!")
      return
    end

    commit.create_github_status(:pending, context: "cocov",
      description: "Checks are running...",
      url: @commit.checks_url)

    checks = begin
      manifest.checks.map do |check|
        { plugin: check.plugin, envs: check.envs }.tap do |data|
          data[:mounts] = prepare_mounts(check)
        end
      end
    rescue Cocov::Manifest::InvalidManifestError => e
      commit.create_github_status(:failure,
        context: "cocov",
        description: e.message,
        url: commit.checks_url)
      nil
    end

    return if checks.nil?

    ActiveRecord::Base.transaction do
      manifest.checks.each do |check|
        commit.check_set.checks.create!(
          plugin_name: Cocov::Manifest.cleanup_plugin_name(check.plugin),
          status: :waiting
        )
      end

      commit.check_set.job_id ||= SecureRandom.uuid
      commit.check_set.status = :queued
      commit.check_set.save!
      Cocov::Redis.authorize_cache_client(commit.check_set.job_id,
        repo_name: commit.repository.name,
        repo_id: commit.repository_id)

      Cocov::Redis.instance.rpush("cocov:checks", {
        check_set_id: commit.check_set.id,
        job_id: commit.check_set.job_id,
        org: Cocov::GITHUB_ORGANIZATION_NAME,
        repo: commit.repository.name,
        repo_id: commit.repository_id,
        sha: commit.sha,
        checks:,
        git_storage: {
          mode: Cocov::GIT_SERVICE_STORAGE_MODE,
          path: GitService.commit_path(commit)
        }
      }.to_json)
    end
  end
end
