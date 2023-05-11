# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Probes" do
  describe "#health" do
    it "blindlessly returns a pong" do
      get "/system/probes/health"
      expect(response).to have_http_status :ok
      expect(response.json).to eq({ "pong" => true })
    end
  end

  describe "#startup" do
    it "returns a 503 in case migrations are pending" do
      allow(Cocov::Status::Migrations).to receive(:up_to_date?).and_return(false)
      get "/system/probes/startup"
      expect(response).to have_http_status :service_unavailable
      expect(response.body).to eq("Migrations pending")
    end

    it "returns a 200 when migrations are up-to-date" do
      allow(Cocov::Status::Migrations).to receive(:up_to_date?).and_return(true)
      get "/system/probes/startup"
      expect(response).to have_http_status :ok
      expect(response.body).to eq("OK")
    end
  end
end
