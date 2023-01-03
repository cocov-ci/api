# frozen_string_literal: true

module V1
  class PingController < V1Controller
    def index
      render json: { pong: true }
    end
  end
end
