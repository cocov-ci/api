# frozen_string_literal: true

module V1
  class TownController < V1Controller
    before_action :ensure_authentication, only: %i[lock_town service_town]
    before_action :ensure_service_token, only: :service_town

    def lock_town
      render json: { ok: true }
    end

    def service_town
      render json: { ok: true }
    end
  end
end
