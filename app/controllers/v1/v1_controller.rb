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
    end

    def ensure_service_token
      error! :auth, :forbidden unless @token.service?
    end

    def paginating(model)
      model
        .page(params[:page] || 1)
        .per(params[:per_page] || nil)
    end
  end
end
