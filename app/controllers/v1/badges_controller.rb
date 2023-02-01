# frozen_string_literal: true

module V1
  class BadgesController < V1Controller
    before_action :ensure_authentication
    before_action :ensure_service_token, only: %i[coverage issues]
    before_action :preload_branch, only: %i[coverage issues]

    def index
      repo = Repository.find_by!(name: params[:name])

      badges_base = Cocov::BADGES_BASE_URL
      return head :no_content if badges_base.empty?

      href = "#{Cocov::UI_BASE_URL}/repos/#{repo.name}"
      render "v1/badges/index", locals: {
        coverage_img: "#{badges_base}/#{repo.name}/coverage",
        coverage_href: href,
        issues_img: "#{badges_base}/#{repo.name}/issues",
        issues_href: href
      }
    end

    def coverage
      render plain: @branch.coverage.presence || "unknown"
    end

    def issues
      render plain: @branch.issues.presence || "unknown"
    end

    private

    def preload_branch
      @repo = Repository.includes(:branches).find_by!(name: params[:name])
      @branch = @repo.find_default_branch
      render plain: "unknown" unless @branch
    end
  end
end
