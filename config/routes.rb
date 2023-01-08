# frozen_string_literal: true

Rails.application.routes.draw do
  post "/auth/begin", to: "session#begin_authentication"
  post "/auth/exchange", to: "session#exchange"

  namespace :v1 do
    # Ping
    get "/ping", to: "ping#index"

    # Secrets
    get "/secrets", to: "secrets#index"
    post "/secrets", to: "secrets#create"
    get "/secrets/data", to: "secrets#show"
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
    get "/repositories/:name/graph/coverage", to: "repositories#graph_coverage"
    get "/repositories/:name/graph/issues", to: "repositories#graph_issues"
    get "/repositories/:name/stats/coverage", to: "repositories#stats_coverage"
    get "/repositories/:name/stats/issues", to: "repositories#stats_issues"

    post "/repositories/:name/settings/regen-token", to: "repository_settings#regen_token"
    post "/repositories/:name/settings/sync-github", to: "repository_settings#sync_github"
    post "/repositories/:name/settings/delete", to: "repository_settings#delete"

    # Badges
    get "/repositories/:name/badges/coverage", to: "badges#coverage"
    get "/repositories/:name/badges/issues", to: "badges#issues"

    # Branches
    get "/repositories/:name/branches", to: "branches#index"
    get "/repositories/:repo_name/branches/:branch_name", to: "branches#show"
    get "/repositories/:repo_name/branches/:branch_name/graph/coverage", to: "branches#graph_coverage"
    get "/repositories/:repo_name/branches/:branch_name/graph/issues", to: "branches#graph_issues"

    # Checks
    get "/repositories/:repo_name/commits/:commit_sha/checks", to: "checks#index"
    get "/repositories/:repo_name/commits/:commit_sha/checks/summary", to: "checks#summary"
    get "/repositories/:repo_name/commits/:commit_sha/checks/:id", to: "checks#show"
    patch "/repositories/:repo_id/commits/:commit_sha/checks", to: "checks#patch"

    # Issues
    put "/repositories/:repo_id/issues", to: "issues#put"
    get "/repositories/:repo_name/commits/:commit_sha/issues", to: "issues#index"
    get "/repositories/:repo_name/commits/:commit_sha/issues/sources", to: "issues#sources"
    get "/repositories/:repo_name/commits/:commit_sha/issues/categories", to: "issues#categories"
    patch "/repositories/:repo_name/commits/:commit_sha/issues/:id", to: "issues#patch"

    # Coverage
    post "/reports", to: "coverage#create"
    put "/repositories/:repo_name/coverage", to: "coverage#put"
    get "/repositories/:repo_name/commits/:commit_sha/coverage/summary", to: "coverage#summary"
    get "/repositories/:repo_name/commits/:commit_sha/coverage", to: "coverage#index"
    get "/repositories/:repo_name/commits/:commit_sha/coverage/file/:id", to: "coverage#show"

    # Secrets
    get "/repositories/:repo_name/secrets", to: "secrets#index"
    post "/repositories/:repo_name/secrets", to: "secrets#create"
    patch "/repositories/:repo_name/secrets/:id", to: "secrets#patch"
    delete "/repositories/:repo_name/secrets/:id", to: "secrets#delete"

    # Private Keys
    get "/repositories/:repo_name/private_keys", to: "private_keys#index"
    post "/repositories/:repo_name/private_keys", to: "private_keys#create"
    delete "/repositories/:repo_name/private_keys/:id", to: "private_keys#delete"

    # GitHub
    post "/github/events", to: "github_events#create"

    unless Rails.env.production?
      get "/locktown", to: "town#lock_town"
      get "/servicetown", to: "town#service_town"
    end
  end
end
