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

    def tool_cache_delete
      error! :cache_settings, :cache_disabled if Cocov::CACHE_SERVICE_URL.nil?

      object = CacheTool.find params[:id]
      Cocov::Redis.request_tool_eviction(object_ids: [object.id])

      head :no_content
    end

    def tool_cache_purge
      error! :cache_settings, :cache_disabled if Cocov::CACHE_SERVICE_URL.nil?
      Cocov::Redis.request_tool_purge

      head :no_content
    end

    def users
      users = paginating(User.all.order(:login))
      counts = RepositoryMember.count_users_permissions(users: users.reject(&:admin?))

      render "v1/admin/users", locals: {
        users:, counts:
      }
    end

    def users_sync_perms
      user = User.find(params[:id])
      UpdateUserPermissionsJob.perform_later(user.id)
      head :no_content
    end

    def users_logout
      user = User.find(params[:id])
      user.tokens.where(kind: :auth).destroy_all
      head :no_content
    end

    def users_delete
      user = User.find(params[:id])
      error! :admin, :cannot_delete_self if user.id == @user.id

      user.destroy

      head :no_content
    end

    def users_update_membership
      user = User.find(params[:id])
      role = params[:role].to_s
      error! :admin, :unknown_role unless %w[user admin].include? role

      error! :admin, :cannot_demote_last_admin if user.admin? && role != "admin" && User.where(admin: true).count == 1

      user.admin = role == "admin"
      user.save!

      head :no_content
    end
  end
end
