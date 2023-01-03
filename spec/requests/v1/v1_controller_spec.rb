# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1" do
  describe "#ensure_authentication" do
    it "rejects requests if header is missing" do
      get "/v1/locktown"
      expect(response).to have_http_status :unauthorized
      expect(response).to be_a_json_error :auth, :no_authorization
    end

    it "rejects requests if header is incorrect" do
      get "/v1/locktown", headers: {
        HTTP_AUTHORIZATION: "lol?"
      }
      expect(response).to have_http_status :unauthorized
      expect(response).to be_a_json_error :auth, :invalid_token
    end

    it "rejects requests if token is invalid or expired" do
      get "/v1/locktown", headers: {
        HTTP_AUTHORIZATION: "bearer invalid"
      }
      expect(response).to have_http_status :unauthorized
      expect(response).to be_a_json_error :auth, :invalid_token
    end

    it "accepts valid requests" do
      user = create(:user)
      get "/v1/locktown", headers: authenticate(user)

      expect(response).to have_http_status :ok
      expect(response).to have_json_body({ ok: true })
    end
  end

  describe "#ensure_service_token" do
    it "rejects authentication tokens" do
      get "/v1/servicetown", headers: authenticated(as: :auth)

      expect(response).to have_http_status :forbidden
      expect(response).to be_a_json_error :auth, :forbidden
    end

    it "rejects personal tokens" do
      get "/v1/servicetown", headers: authenticated(as: :personal)

      expect(response).to have_http_status :forbidden
      expect(response).to be_a_json_error :auth, :forbidden
    end

    it "accepts service tokens" do
      get "/v1/servicetown", headers: authenticated(as: :service)

      expect(response).to have_http_status :ok
      expect(response).to have_json_body({ ok: true })
    end
  end
end
