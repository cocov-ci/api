# frozen_string_literal: true

require "sidekiq/web"

Rails.application.routes.draw do
  post "/auth/begin", to: "session#begin_authentication"
  post "/auth/exchange", to: "session#exchange"

  mount Sidekiq::Web => "/sidekiq", :constraints => Cocov::SidekiqRouteConstraint.new

  namespace :v1 do
    # Ping
    get "/ping", to: "ping#index"

    # Secrets
    get "/secrets", to: "secrets#index"
    post "/secrets", to: "secrets#create"
    get "/secrets/data", to: "secrets#show"
    post "/secrets/check_name", to: "secrets#check_name"
    patch "/secrets/:id", to: "secrets#patch"
    delete "/secrets/:id", to: "secrets#delete"

    # Public Keys
    get "/private_keys", to: "private_keys#index"
    post "/private_keys", to: "private_keys#create"
    delete "/private_keys/:id", to: "private_keys#delete"

    # Repositories
    get "/repositories", to: "repositories#index"
    post "/repositories", to: "repositories#create"
    get "/repositories/$search", to: "repositories#search"
    get "/repositories/:name", to: "repositories#show"
    get "/repositories/:name/graphs", to: "repositories#graphs"
    get "/repositories/:name/stats/coverage", to: "repositories#stats_coverage"
    get "/repositories/:name/stats/issues", to: "repositories#stats_issues"

    get "/repositories/:name/settings", to: "repository_settings#index"
    post "/repositories/:name/settings/regen-token", to: "repository_settings#regen_token"
    post "/repositories/:name/settings/sync-github", to: "repository_settings#sync_github"
    post "/repositories/:name/settings/delete", to: "repository_settings#delete"

    # Badges
    get "/repositories/:name/badges/coverage", to: "badges#coverage"
    get "/repositories/:name/badges/issues", to: "badges#issues"
    get "/repositories/:name/badges", to: "badges#index"

    # Branches
    get "/repositories/:name/branches", to: "branches#index"
    get "/repositories/:repo_name/branches/graphs/*branch_name", to: "branches#graphs"
    get "/repositories/:repo_name/branches/top_issues/*branch_name", to: "branches#top_issues"
    get "/repositories/:repo_name/branches/*branch_name", to: "branches#show"

    # Checks
    get "/repositories/:repo_name/commits/:commit_sha/checks", to: "checks#index"
    get "/repositories/:repo_name/commits/:commit_sha/checks/summary", to: "checks#summary"
    get "/repositories/:repo_name/commits/:commit_sha/checks/:id", to: "checks#show"
    patch "/repositories/:repo_id/commits/:commit_sha/checks", to: "checks#patch"
    delete "/repositories/:repo_id/commits/:commit_sha/checks", to: "checks#cancel"
    post "/repositories/:repo_id/commits/:commit_sha/checks/wrap_up", to: "checks#wrap_job_up"
    post "/repositories/:repo_id/commits/:commit_sha/checks/re_run", to: "checks#re_run"
    post "/repositories/:repo_id/commits/:commit_sha/check_set/notify_processing", to: "checks#notify_processing"

    # Issues
    put "/repositories/:repo_id/issues", to: "issues#put"
    get "/repositories/:repo_name/commits/:commit_sha/issues", to: "issues#index"
    get "/repositories/:repo_name/commits/:commit_sha/issues/sources", to: "issues#sources"
    get "/repositories/:repo_name/commits/:commit_sha/issues/categories", to: "issues#categories"
    # patch "/repositories/:repo_name/commits/:commit_sha/issues/:id", to: "issues#patch"

    # Coverage
    post "/reports", to: "coverage#create"
    put "/repositories/:repo_name/coverage", to: "coverage#put"
    get "/repositories/:repo_name/commits/:commit_sha/coverage/summary", to: "coverage#summary"
    get "/repositories/:repo_name/commits/:commit_sha/coverage", to: "coverage#index"
    get "/repositories/:repo_name/commits/:commit_sha/coverage/file/:id", to: "coverage#show"

    # Secrets
    get "/repositories/:repo_name/secrets", to: "secrets#index"
    post "/repositories/:repo_name/secrets", to: "secrets#create"
    post "/repositories/:repo_name/secrets/check_name", to: "secrets#check_name"
    patch "/repositories/:repo_name/secrets/:id", to: "secrets#patch"
    delete "/repositories/:repo_name/secrets/:id", to: "secrets#delete"

    # Private Keys
    get "/repositories/:repo_name/private_keys", to: "private_keys#index"
    post "/repositories/:repo_name/private_keys", to: "private_keys#create"
    delete "/repositories/:repo_name/private_keys/:id", to: "private_keys#delete"

    # Admin
    post "/admin/sidekiq_panel_token", to: "admin#sidekiq_panel_token"
    get "/admin/sidekiq_panel", to: "admin#sidekiq_panel"

    # GitHub
    post "/github/events", to: "github_events#create"

    unless Rails.env.production?
      get "/locktown", to: "town#lock_town"
      get "/servicetown", to: "town#service_town"
    end
  end
end
