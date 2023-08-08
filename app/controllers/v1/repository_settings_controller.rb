# frozen_string_literal: true

module V1
  class RepositorySettingsController < V1Controller
    before_action :ensure_authentication
    require_permission(:maintainer, only: %i[regen_token sync_github])
    require_permission(:admin, only: :delete)
    before_action :load_repository

    def index
      level = @repository.permission_level_for @user
      maintainer = %i[admin maintainer].include? level
      admin = level == :admin
      render "v1/repository_settings/index", locals: {
        repo: @repository,
        secrets_count: @repository.secrets.count,
        permissions: {
          can_regen_token: maintainer || admin,
          can_sync_github: maintainer || admin,
          can_delete: admin
        }
      }
    end

    def regen_token
      @repository.token = nil
      @repository.save!

      render json: {
        new_token: @repository.token
      }
    end

    def sync_github
      repo = Cocov::GitHub.app.repo(@repository.github_id)
      @repository.name = repo.name
      @repository.description = repo.description

      name_changed = @repository.name_changed?
      @repository.save!

      UpdateRepoPermissionsJob.perform_later(repo.id)

      return render json: { new_name: repo.name } if name_changed

      head :no_content
    end

    def delete
      DestroyRepositoryJob.perform_later(@repository.id)
      head :no_content
    end

    private

    def load_repository
      @repository = Repository.with_context(auth_context).find_by! name: params[:name]
    end
  end
end
