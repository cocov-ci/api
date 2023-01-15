# frozen_string_literal: true

module Cocov
  GITHUB_ORGANIZATION_NAME = ENV.fetch("COCOV_GITHUB_ORG_NAME", "")

  GITHUB_APP_ID = ENV.fetch("COCOV_GITHUB_APP_ID", "")
  GITHUB_APP_PRIVATE_KEY = Base64.decode64(ENV.fetch("COCOV_GITHUB_APP_PRIVATE_KEY", ""))
  GITHUB_APP_INSTALLATION_ID = ENV.fetch("COCOV_GITHUB_APP_INSTALLATION_ID", "")

  GITHUB_OAUTH_CLIENT_ID = ENV.fetch("COCOV_GITHUB_OAUTH_CLIENT_ID", "")
  GITHUB_OAUTH_CLIENT_SECRET = ENV.fetch("COCOV_GITHUB_OAUTH_CLIENT_SECRET", "")

  GITHUB_WEBHOOK_SECRET_KEY = ENV.fetch("COCOV_GITHUB_WEBHOOK_SECRET_KEY", "")

  UI_BASE_URL = ENV.fetch("COCOV_UI_BASE_URL", "http://localhost:4000").gsub(%r{/$}, "")
  API_BASE_URL = ENV.fetch("COCOV_API_BASE_URL", "http://localhost:3000")

  REDIS_URL = ENV.fetch("COCOV_REDIS_URL", "redis://redis:6379/0")
  REDIS_CACHE_URL = ENV.fetch("COCOV_REDIS_CACHE_URL", "redis://redis:6379/1")
  SIDEKIQ_REDIS_URL = ENV.fetch("COCOV_SIDEKIQ_REDIS_URL", "redis://redis:6379/2")

  ALLOW_OUTSIDE_COLLABORATORS = ENV.fetch("COCOV_ALLOW_OUTSIDE_COLLABORATORS", "true").casecmp("true").zero?

  GIT_SERVICE_STORAGE_MODE = ENV.fetch("COCOV_GIT_SERVICE_STORAGE_MODE", "local").to_sym
  GIT_SERVICE_LOCAL_STORAGE_PATH = ENV.fetch("COCOV_GIT_SERVICE_LOCAL_STORAGE_PATH", ".git_storage")
  GIT_SERVICE_S3_STORAGE_BUCKET_NAME = ENV.fetch("GIT_SERVICE_S3_STORAGE_BUCKET_NAME", "")

  CRYPTOGRAPHIC_KEY = ENV.fetch("COCOV_CRYPTOGRAPHIC_KEY", nil)
end
