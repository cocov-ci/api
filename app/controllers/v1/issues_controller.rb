# frozen_string_literal: true

module V1
  class IssuesController < V1Controller
    before_action :ensure_authentication
    before_action :ensure_service_token, only: :put
    before_action :load_filtered_issues, only: %i[sources categories index]

    def index
      render "v1/issues/index", locals: {
        issues: paginating(@issues),
        repo: @repo,
        commit: @commit
      }
    end

    def put
      error! :issues, :json_required unless request.format.json?

      data = begin
        IssueRegisteringService.validate(params)
      rescue Cocov::SchemaValidator::ValidationError => e
        error! :issues, :validation_error,
          expected: e.expected,
          received: e.received,
          path: e.path.join(".")
      end

      repo = Repository.find(params[:repo_id])
      IssueRegisteringService.call(data, repo)

      head :no_content
    end

    def sources
      from_issues = Issue.where(commit_id: @commit.id).group(:check_source).count
      result = @commit.checks.pluck(:plugin_name).index_with do |name|
        from_issues.fetch(name, 0)
      end
      render json: result
    end

    def categories
      from_issues = Issue.where(commit_id: @commit.id).group(:kind).count
      result = Issue.kinds.keys.index_with do |name|
        from_issues.fetch(name, 0)
      end
      render json: result
    end

    private

    def load_filtered_issues
      filter = {}
      filter[:check_source] = params[:source] if params[:source].present?
      filter[:kind] = params[:category] if params[:category].present?

      error! :issues, :invalid_kind if filter.key?(:kind) && !Issue.kinds.key?(filter[:kind])

      @repo = Repository.with_context(auth_context).find_by!(name: params[:repo_name])
      @commit = @repo.commits.includes(:user).find_by!(sha: params[:commit_sha])

      @issues = if filter.empty?
                  @commit.issues
                else
                  @commit.issues.where(**filter)
                end
    end
  end
end
