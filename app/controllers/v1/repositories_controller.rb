# frozen_string_literal: true

module V1
  class RepositoriesController < V1Controller
    before_action :ensure_authentication

    def index
      repos = paginating Repository
        .includes(:branches)
        .order(name: :asc)

      render "v1/repositories/index",
        locals: { repos: }
    end

    def search
      term = params[:term]
      error! :repositories, :missing_term if term.blank?

      repos = Repository.by_fuzzy_name(term)

      render "v1/repositories/search",
        locals: { repos: }
    end

    def show
      repo = Repository.includes(:branches).find_by!(name: params[:name])
      render "v1/repositories/show",
        locals: { repo: }
    end

    def create
      error! :repositories, :already_exists if Repository.exists?(name: params[:name])

      gh_repo = begin
        Cocov::GitHub.app.repo("#{Cocov::GITHUB_ORGANIZATION_NAME}/#{params[:name]}")
      rescue Octokit::NotFound
        error! :repositories, :not_on_github
      end

      repo = Repository.new(
        name: gh_repo.name,
        description: gh_repo.description,
        default_branch: gh_repo.default_branch
      )
      repo.save!

      render "v1/repositories/create",
        locals: { repo: },
        status: :created
    end

    def graph_coverage
      render json: MonthlyGrapherService.call(params[:name], :coverage)
    end

    def graph_issues
      render json: MonthlyGrapherService.call(params[:name], :issues)
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

      repo = Repository.includes(:branches).find_by!(name: params[:name])
      branch_id = repo.find_default_branch&.id || 0

      yield repo, branch_id, from, to
    end
  end
end
