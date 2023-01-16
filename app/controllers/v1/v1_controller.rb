# frozen_string_literal: true

module V1
  class V1Controller < ApplicationController
    def ensure_authentication
      key = request.headers["HTTP_AUTHORIZATION"]
      error! :auth, :no_authorization if key.blank?
      error! :auth, :invalid_token unless key.downcase.start_with? "bearer "
      @token = UserToken.by_token(key.split.last)
      if @token.nil?
        @token = ServiceToken.by_token(key.split.last)
      else
        @user = @token.user
      end

      error! :auth, :invalid_token unless @token
      @token.touch_last_used if @token.tracks_last_used?
    end

    def ensure_administrative_privileges
      error! :auth, :forbidden unless @user&.admin?
    end

    def ensure_service_token
      error! :auth, :forbidden unless @token.service?
    end

    def paginating(model)
      model
        .page(params[:page] || 1)
        .per(params[:per_page] || nil)
    end

    def self.require_permission(level, **kwargs)
      before_action -> { require_actor_permission(level) }, **kwargs
    end

    def require_actor_permission(level)
      @_required_action_permission_level = level
    end

    def auth_context
      return [:service, nil, nil] if @token.is_a?(ServiceToken)

      [:user, @user, @_required_action_permission_level]
    end
  end
end
