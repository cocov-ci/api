class ProbesController < ApplicationController
  def health
    render json: { pong: true }
  end

  def startup
    render plain: "OK", status: :ok and return if Cocov::Status::Migrations.up_to_date?

    render plain: "Migrations pending", status: :service_unavailable
  end
end
