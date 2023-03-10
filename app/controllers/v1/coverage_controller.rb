# frozen_string_literal: true

module V1
  class CoverageController < V1Controller
    before_action :ensure_authentication, except: :create
    before_action :ensure_repository_token, only: :create

    def index
      repo = Repository.with_context(auth_context).find_by! name: params[:repo_name]
      commit = repo.commits.includes(:coverage, :user).find_by! sha: params[:commit_sha]
      coverage = commit.coverage
      files = commit.coverage&.files&.select(:id, :file, :percent_covered)&.order(:percent_covered)

      render "v1/coverage/index",
        locals: { repo:, commit:, coverage:, files: }
    end

    def show
      repo = Repository.with_context(auth_context).find_by! name: params[:repo_name]
      commit = repo.commits.includes(:coverage).find_by! sha: params[:commit_sha]
      file = commit.coverage.files.find(params[:id])

      source = Cocov::Highlighter.new(commit, path: file.file).format
      lines = Cocov::CoverageParser.parse(file.raw_data)
      blocks = Cocov::CoverageParser::BlockComposer.group(lines)

      render "v1/coverage/show",
        locals: { file:, source:, blocks: }
    end

    def create
      data = params[:data]
      commit_sha = params[:commit_sha]

      error! :report, :missing_data if data.blank?
      error! :report, :missing_commit_sha if commit_sha.blank?

      Cocov::Redis.lock("commit:#{@repo.id}:#{commit_sha}", 1.minute) do
        commit = @repo.commits.find_by(sha: commit_sha)
        if commit
          commit.reset_coverage! status: :queued
          ProcessCoverageJob.perform_later(@repo.id, commit_sha, data.permit!.to_json)
          next
        end

        Cocov::Redis.instance.set("commit:coverage:#{@repo.id}:#{commit_sha}", data, ex: 2.hours)
      end

      head :no_content
    end

    def summary
      repo = Repository.with_context(auth_context).find_by!(name: params[:repo_name])
      commit = repo.commits.find_by!(sha: params[:commit_sha])
      cov = commit.coverage

      return head :no_content unless cov

      least_covered = []
      least_covered = cov.files.order(percent_covered: :asc).limit(10) if cov.completed?

      render "v1/coverage/summary",
        locals: { cov:, least_covered:, repo:, commit: }
    end

    private

    def ensure_repository_token
      key = request.headers["HTTP_AUTHORIZATION"]
      error! :auth, :no_authorization if key.blank?
      error! :auth, :invalid_token unless key.downcase.start_with? "token "
      @repo = Repository.find_by(token: key.split.last)
      error! :auth, :forbidden unless @repo
    end
  end
end
