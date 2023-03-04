# frozen_string_literal: true

class UpdateOrganizationReposJob < ApplicationJob
  queue_as :default

  def perform
    app = Cocov::GitHub.app

    all_repos = app.org_repos(Cocov::GITHUB_ORGANIZATION_NAME)
    etag = app.last_response.headers[:etag]

    all_repos.map! do |repo|
      repo.to_h.slice(:id, :name, :description, :created_at, :pushed_at)
    end

    all_repos.sort_by! { _1[:name] }

    Cocov::Redis.set_organization_repositories(items: all_repos, etag:)
  end
end
