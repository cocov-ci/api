# frozen_string_literal: true

module V1
  class BranchesController < V1Controller
    before_action :ensure_authentication

    def index
      branches = paginating Repository
        .with_context(auth_context)
        .find_by!(name: params[:name])
        .branches
        .includes(head: :user)
        .order(name: :asc)

      render "v1/branches/index", locals: { branches: }
    end

    def show
      branch = Repository
        .with_context(auth_context)
        .find_by!(name: params[:repo_name])
        .branches
        .includes(head: :user)
        .find_by!(name: params[:branch_name])

      render "v1/branches/show", locals: { branch: }
    end

    def graphs
      repo = Repository.with_context(auth_context).find_by!(name: params[:repo_name])
      issues = MonthlyGrapherService.call(repo, :issues, branch: params[:branch_name])
      coverage = MonthlyGrapherService.call(repo, :coverage, branch: params[:branch_name])
      render json: { issues:, coverage: }
    end

    def top_issues
      repo = Repository
        .with_context(auth_context)
        .find_by!(name: params[:repo_name])
      branch = Branch.find_by(repository: repo, name: params[:branch_name])

      render json: branch
        .head
        .issues
        .group(:kind)
        .count
        .entries
        .sort_by(&:last)
        .reverse
        .to_h
    end
  end
end
