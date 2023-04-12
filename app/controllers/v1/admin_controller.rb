# frozen_string_literal: true

module V1
  class AdminController < V1Controller
    before_action :ensure_authentication, except: :sidekiq_panel
    before_action :ensure_administrative_privileges, except: :sidekiq_panel

    def sidekiq_panel_token
      auth_id = Cocov::SidekiqRouteConstraint.generate_exchange_token(@user)
      render json: { token: auth_id }
    end

    def sidekiq_panel
      auth_id = Cocov::SidekiqRouteConstraint.session_for_exchange_token(params[:token])
      session[:cocov_sidekiq_session_id] = auth_id
      redirect_to "/sidekiq"
    end

    def tool_cache
      if Cocov::CACHE_SERVICE_URL.nil?
        render "v1/admin/tool_cache", locals: {
          enabled: false
        }
        return
      end

      artifacts = CacheTool.all.order("last_used_at DESC NULLS LAST")

      render "v1/admin/tool_cache", locals: {
        enabled: true,
        artifacts: paginating(artifacts)
      }
    end

    def delete_tool_cache
      error! :cache_settings, :cache_disabled if Cocov::CACHE_SERVICE_URL.nil?

      object = CacheTool.find params[:id]
      Cocov::Redis.request_tool_eviction(object_ids: [object.id])

      head :no_content
    end

    def purge_tool_cache
      error! :cache_settings, :cache_disabled if Cocov::CACHE_SERVICE_URL.nil?
      Cocov::Redis.request_tool_purge

      head :no_content
    end
  end
end
