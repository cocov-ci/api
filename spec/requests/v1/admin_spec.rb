# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Issues" do
  before do
    mock_redis!
    stub_crypto_key!
  end

  describe "#sidekiq_panel_token" do
    it "returns forbidden for non-admin users" do
      post "/v1/admin/sidekiq_panel_token",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns a token for admin users" do
      @user = create(:user, :admin)
      post "/v1/admin/sidekiq_panel_token",
        headers: authenticated
      expect(response).to have_http_status(:ok)
    end
  end

  describe "#sidekiq_panel" do
    it "exchanges a token and redirects to /sidekiq" do
      @user = create(:user, :admin)
      post "/v1/admin/sidekiq_panel_token",
        headers: authenticated
      expect(response).to have_http_status(:ok)
      token = response.json[:token]

      get "/v1/admin/sidekiq_panel?token=#{token}",
        headers: authenticated
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/sidekiq")
    end
  end
end
