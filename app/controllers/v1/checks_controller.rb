# frozen_string_literal: true

module V1
  class ChecksController < V1Controller
    before_action :ensure_authentication
    before_action :ensure_service_token, only: :patch

    def index
      checks = Repository.find_by!(name: params[:repo_name])
        .commits.includes(:checks).find_by!(sha: params[:commit_sha])
        .checks
        .order(plugin_name: :asc)

      render "v1/checks/index",
        locals: { checks: }
    end

    def show
      check = Repository.find_by!(name: params[:repo_name])
        .commits.find_by!(sha: params[:commit_sha])
        .checks
        .find(params[:id])

      render "v1/checks/show",
        locals: { check: }
    end

    def patch
      plugin_name = params[:plugin_name]
      error! :checks, :missing_plugin_name if plugin_name.blank?

      new_status = params[:status]
      error! :checks, :missing_status if new_status.blank?
      error! :checks, :invalid_status unless Check.statuses.key? new_status

      error_output = params[:error_output]
      error! :checks, :missing_error_output if new_status == "errored" && error_output.blank?

      updates = {
        status: new_status
      }

      check = Repository.find(params[:repo_id])
        .commits.find_by!(sha: params[:commit_sha])
        .checks
        .find_by!(plugin_name: params[:plugin_name])

      case new_status
      when "running"
        check.commit.checks_processing!
        updates[:started_at] = Time.zone.now
      when "succeeded"
        updates[:error_output] = nil
        updates[:started_at] = Time.zone.now if check.started_at.nil?
        updates[:finished_at] = Time.zone.now
      when "errored"
        updates[:started_at] = Time.zone.now if check.started_at.nil?
        updates[:finished_at] = Time.zone.now
        updates[:error_output] = error_output
      end
      check.update!(**updates)

      head :no_content
    end

    def summary
      commit = Repository.find_by!(name: params[:repo_name])
        .commits.find_by!(sha: params[:commit_sha])
      checks = commit.checks.order(plugin_name: :asc)
      issues_count = commit.issues.group(:check_source).count

      render "v1/checks/summary",
        locals: { checks:, issues_count: }
    end
  end
end
