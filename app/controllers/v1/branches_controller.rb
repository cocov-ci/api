# frozen_string_literal: true

module V1
  class BranchesController < V1Controller
    before_action :ensure_authentication

    def index
      repository = Repository
        .with_context(auth_context)
        .find_by!(name: params[:name])

      branches = repository.branches.pluck(:name).sort

      branches.delete(repository.default_branch)&.tap do |name|
        branches.prepend(name) if name
      end

      render json: { branches: }
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
      branch = repo.branches.find_by!(name: params[:branch_name])
      issues = MonthlyGrapherService.call(repo, :issues, branch:)
      coverage = MonthlyGrapherService.call(repo, :coverage, branch:)
      render json: { issues:, coverage: }
    end

    def top_issues
      repo = Repository
        .with_context(auth_context)
        .find_by!(name: params[:repo_name])
      branch = Branch.find_by(repository: repo, name: params[:branch_name])
      commit = branch.head
      data = {}

      if commit
        data = commit
          .issues
          .group(:kind)
          .count
          .entries
          .sort_by(&:last)
          .reverse
          .to_h
      end

      render json: data
    end
  end
end
