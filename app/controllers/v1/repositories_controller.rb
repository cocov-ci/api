# frozen_string_literal: true

module V1
  class RepositoriesController < V1Controller
    include V1Helper

    before_action :ensure_authentication

    def index
      repos = Repository
        .with_context(auth_context)
        .includes(:branches)

      repos = if (search = params[:search_term].presence)
        repos.by_fuzzy_name(search)
      else
        repos.order(name: :ASC)
      end

      render "v1/repositories/index",
        locals: { repos: paginating(repos) }
    end

    def show
      repo = Repository
        .with_context(auth_context)
        .includes(:branches)
        .find_by!(name: params[:name])
      render "v1/repositories/show",
        locals: { repo: }
    end

    def create
      gh_repo = begin
        Cocov::GitHub.app.repo("#{Cocov::GITHUB_ORGANIZATION_NAME}/#{params[:name]}")
      rescue Octokit::NotFound
        error! :repositories, :not_on_github
      end

      error! :repositories, :already_exists if Repository.exists?(github_id: gh_repo.id)

      repo = Repository.transaction do
        Repository.create_from_github(gh_repo).tap do |r|
          next unless @user

          # This temporarily grants the user an admin account, which will then
          # be updated (hopefully soon), by UpdateRepoPermissionsJob.
          RepositoryMember.create! repository: r,
            level: :admin,
            github_member_id: @user.github_id
        end
      end

      UpdateRepoPermissionsJob.perform_later(repo.id)

      render "v1/repositories/create",
        locals: { repo: },
        status: :created
    end

    def graphs
      repo = Repository.with_context(auth_context).find_by! name: params[:name]
      coverage_points = MonthlyGrapherService.call(repo, :coverage)
      issues_points = MonthlyGrapherService.call(repo, :issues)

      render json: { coverage: coverage_points, issues: issues_points }
    end

    def stats_coverage
      value = stats_params do |repo, branch, from, to|
        CoverageHistory.history_for(repo, branch, from, to)
          .map { { date: _1[:date].to_date.iso8601, value: _1[:value] } }
      end
      render json: value
    end

    def stats_issues
      value = stats_params do |repo, branch, from, to|
        IssueHistory.history_for(repo, branch, from, to)
          .map { { date: _1[:date].to_date.iso8601, value: _1[:value] } }
      end
      render json: value
    end

    REPOSITORIES_PER_PAGE = 50

    def org_repos_response(items)
      page = [params[:page].presence.to_i || 1, 1].max - 1
      offset_start = page * REPOSITORIES_PER_PAGE
      offset_end = offset_start + REPOSITORIES_PER_PAGE
      total_pages = (items.length.to_f / REPOSITORIES_PER_PAGE).ceil
      next_page = page + 2 > total_pages ? nil : page + 2
      prev_page = (page - 1).negative? ? nil : page

      items = items[offset_start...offset_end]

      known_repos = Repository.where(github_id: items.pluck("id")).pluck(:github_id)
      items.map! do |repo|
        id = repo.delete("id")
        repo.delete(:similarity)
        repo.merge(
          status: known_repos.include?(id) ? :present : :absent
        )
      end

      result = {
        status: :ok,
        items:,
        total_pages:,
        current_page: page + 1
      }

      result[:next_page] = update_page_param(next_page) if next_page
      result[:prev_page] = update_page_param(prev_page) if prev_page

      result
    end

    def search_org_repos(items, term:)
      term_trig = Cocov::Trigram.trigrams_of(term)
      items.map! do |item|
        item_trig = Cocov::Trigram.trigrams_of(item["name"])
        item.merge(
          similarity: Cocov::Trigram.trigram_similarity(term_trig, item_trig)
        )
      end

      items
        .filter { _1[:similarity] >= 0.3 }
        .sort_by { _1[:similarity] }
        .reverse
        .first(REPOSITORIES_PER_PAGE)
    end

    def org_repos
      repos = Cocov::Redis.organization_repositories
      if repos.nil?
        Cocov::Redis.set_organization_repositories_updating
        UpdateOrganizationReposJob.perform_later
        render json: { status: :updating }
        return
      end

      if repos[:status] == :updating
        render json: { status: :updating }
        return
      end

      items = repos[:items]

      items = search_org_repos(items, term: params[:search_term]) if params[:search_term].presence

      result = org_repos_response(items)
      result[:last_updated] = repos[:updated_at]
      render json: result
    end

    def update_org_repos
      UpdateOrganizationReposJob.perform_later
      head :no_content
    end

    private

    def stats_params
      from = params[:from]
      to = params[:to]

      error! :repositories, :missing_from_date if from.blank?
      error! :repositories, :missing_to_date if to.blank?

      from = begin
        Time.parse(from).utc.beginning_of_day
      rescue ArgumentError
        error! :repositories, :invalid_from_date
      end

      to = begin
        Time.parse(to).utc.end_of_day
      rescue ArgumentError
        error! :repositories, :invalid_to_date
      end

      error! :repositories, :stats_range_too_large, max: 100 if (to.to_date - from.to_date).to_i > 100

      repo = Repository
        .with_context(auth_context)
        .includes(:branches)
        .find_by!(name: params[:name])
      branch_id = repo.find_default_branch&.id || 0

      yield repo, branch_id, from, to
    end
  end
end
