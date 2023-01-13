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

    def graph_coverage
      repo = Repository.with_context(auth_context).find_by!(name: params[:repo_name])
      render json: MonthlyGrapherService.call(repo, :coverage, branch: params[:branch_name])
    end

    def graph_issues
      repo = Repository.with_context(auth_context).find_by!(name: params[:repo_name])
      render json: MonthlyGrapherService.call(repo, :issues, branch: params[:branch_name])
    end
  end
end
