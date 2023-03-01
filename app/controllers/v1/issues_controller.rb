# frozen_string_literal: true

module V1
  class IssuesController < V1Controller
    before_action :ensure_authentication
    before_action :ensure_service_token, only: :put
    before_action :load_parents, only: %i[ignore cancel_ignore sources categories states]
    before_action :load_filtered_issues, only: :index

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

    def ignore
      mode = params[:mode]
      error! :issues, :invalid_ignore_mode unless %w[ephemeral permanent].include? mode

      issue = @commit.issues.includes(:ignore_user, :ignore_rule).find(params[:id])

      unless issue.ignored?
        ignore_params = { user: @user, reason: params[:reason] }

        if mode == "ephemeral"
          issue.ignore!(**ignore_params)
        else
          issue.ignore_permanently!(**ignore_params)
        end

        @commit.reload
        @commit.update_github_issue_count_status!
      end

      render "v1/issues/_issue", locals: { issue: }
    end

    def cancel_ignore
      issue = @commit.issues.find(params[:id])
      issue.clean_ignore!

      @commit.update_github_issue_count_status! if issue.saved_change_to_ignored_at?

      render "v1/issues/_issue", locals: { issue: }
    end

    def states
      issue = Issue.count_for_commit(@commit.id)
      render json: issue
    end

    def sources
      from_issues = Issue
        .where(commit_id: @commit.id, ignored_at: nil)
        .group(:check_source)
        .count

      result = @commit.checks.pluck(:plugin_name).index_with do |name|
        from_issues.fetch(name, 0)
      end

      render json: result
    end

    def categories
      from_issues = Issue
        .where(commit_id: @commit.id, ignored_at: nil)
        .group(:kind)
        .count

      result = Issue.kinds.keys.index_with do |name|
        from_issues.fetch(name, 0)
      end
      render json: result
    end

    private

    def load_parents
      return if @parents_loaded

      @parents_loaded = true

      @repo = Repository.with_context(auth_context).find_by!(name: params[:repo_name])
      @commit = @repo.commits.includes(:user).find_by!(sha: params[:commit_sha])
    end

    def load_filtered_issues
      load_parents

      filter = {}
      filter[:check_source] = params[:source] if params[:source].present?
      filter[:kind] = params[:category] if params[:category].present?

      error! :issues, :invalid_kind if filter.key?(:kind) && !Issue.kinds.key?(filter[:kind])

      @issues = if filter.empty?
        @commit.issues
      else
        @commit.issues.where(**filter)
      end

      case params[:state].presence
      when "ignored"
        @issues = @issues.where.not(ignored_at: nil)
      when "active", nil
        @issues = @issues.where(ignored_at: nil)
      when "all"
        # Do nothing
      else
        error! :issues, :invalid_state
      end
    end
  end
end
