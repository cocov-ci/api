# frozen_string_literal: true

module V1
  class BadgesController < V1Controller
    before_action :ensure_authentication
    before_action :ensure_service_token
    before_action :preload_branch

    def coverage
      render plain: @branch.coverage.presence || "unknown"
    end

    def issues
      render plain: @branch.issues.presence || "unknown"
    end

    private

    def preload_branch
      repo = Repository.includes(:branches).find_by!(name: params[:name])
      @branch = repo.find_default_branch
      render plain: "unknown" unless @branch
    end
  end
end
