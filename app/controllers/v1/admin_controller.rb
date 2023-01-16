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
  end
end
