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

  describe "#tool_cache" do
    it "returns forbidden for non-admin users" do
      get "/v1/admin/tool_cache",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "indicates in case cache is disabled" do
      with_caching_disabled
      @user = create(:user, :admin)
      get "/v1/admin/tool_cache",
        headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json[:enabled]).to be false
    end

    it "returns a list of artifacts" do
      with_caching_enabled
      tool = create(:cache_tool)
      @user = create(:user, :admin)
      get "/v1/admin/tool_cache",
        headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json[:enabled]).to be true
      expect(response.json[:artifacts].length).to eq 1

      item = response.json[:artifacts].first
      expect(item[:id]).to eq tool.id
      expect(item[:name]).to eq tool.name
      expect(item[:name_hash]).to eq tool.name_hash
      expect(item[:size]).to eq tool.size
      expect(item[:engine]).to eq tool.engine
      expect(item[:mime]).to eq tool.mime
    end
  end

  describe "#delete_tool_cache" do
    it "returns forbidden for non-admin users" do
      get "/v1/admin/tool_cache",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns an error in case cache is disabled" do
      with_caching_disabled
      @user = create(:user, :admin)
      delete "/v1/admin/tool_cache/1",
        headers: authenticated
      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:cache_settings, :cache_disabled)
    end

    it "returns 404 in case the item does not exist" do
      with_caching_enabled
      @user = create(:user, :admin)
      delete "/v1/admin/tool_cache/0",
        headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "deletes an item and requests its removal" do
      mock_redis!
      with_caching_enabled

      tool = create(:cache_tool)
      @user = create(:user, :admin)
      delete "/v1/admin/tool_cache/#{tool.id}",
        headers: authenticated
      expect(response).to have_http_status(:no_content)
      expect(@redis.llen("cocov:cached:housekeeping_tasks")).to eq 1
      obj = JSON.parse(@redis.lpop("cocov:cached:housekeeping_tasks"), symbolize_names: true)

      expect(obj[:task]).to eq "evict-tool"
      expect(obj[:objects]).to eq [tool.id]
    end
  end

  describe "#purge_tool_cache" do
    it "returns forbidden for non-admin users" do
      post "/v1/admin/tool_cache/purge",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns an error in case cache is disabled" do
      with_caching_disabled
      @user = create(:user, :admin)
      post "/v1/admin/tool_cache/purge",
        headers: authenticated
      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:cache_settings, :cache_disabled)
    end

    it "deletes an item and requests its removal" do
      mock_redis!
      with_caching_enabled

      @user = create(:user, :admin)
      post "/v1/admin/tool_cache/purge",
        headers: authenticated
      expect(response).to have_http_status(:no_content)
      expect(@redis.llen("cocov:cached:housekeeping_tasks")).to eq 1
      obj = JSON.parse(@redis.lpop("cocov:cached:housekeeping_tasks"), symbolize_names: true)

      expect(obj[:task]).to eq "purge-tool"
    end
  end
end
