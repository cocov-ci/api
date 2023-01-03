# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Ping" do
  it "replies pings" do
    get "/v1/ping"
    expect(response).to have_http_status(:ok)
    expect(response.json).to eq({ "pong" => true })
  end
end
