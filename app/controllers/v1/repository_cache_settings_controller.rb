# frozen_string_literal: true

module V1
  class RepositoryCacheSettingsController < V1Controller
    before_action :ensure_authentication
    before_action :load_repository

    def index
      if Cocov::CACHE_SERVICE_URL.nil?
        render "v1/repository_cache_settings/index", locals: {
          enabled: false,
          repo: @repository
        }
        return
      end

      artifacts = @repository.cache_artifacts.order("last_used_at DESC NULLS LAST")
      repository_usage = @repository.cache_size
      max_size = Cocov::REPOSITORY_CACHE_MAX_SIZE

      render "v1/repository_cache_settings/index", locals: {
        enabled: true,
        artifacts: paginating(artifacts),
        repo: @repository,
        usage: repository_usage,
        max_size:
      }
    end

    def delete
      error! :cache_settings, :cache_disabled if Cocov::CACHE_SERVICE_URL.nil?

      object = @repository.cache_artifacts.find params[:id]
      Cocov::Redis.request_cache_eviction(@repository.id, object_ids: [object.id])

      head :no_content
    end

    def purge
      error! :cache_settings, :cache_disabled if Cocov::CACHE_SERVICE_URL.nil?

      Cocov::Redis.request_cache_purge(@repository.id)
      ActiveRecord::Base.transaction do
        @repository.cache_artifacts.delete_all
        @repository.compute_cache_size!
      end

      head :no_content
    end

    private

    def load_repository
      @repository = Repository.with_context(auth_context).find_by! name: params[:name]
    end
  end
end
