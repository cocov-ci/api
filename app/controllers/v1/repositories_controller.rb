# frozen_string_literal: true

module V1
  class RepositoriesController < V1Controller
    before_action :ensure_authentication

    def index
      repos = Repository
        .with_context(auth_context)
        .includes(:branches)

      repos = if (search = params[:search_term])
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

    private

    def no_history
      head :no_content
    end

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
