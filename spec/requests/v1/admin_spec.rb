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

  describe "#users" do
    it "returns forbidden for non-admin users" do
      get "/v1/admin/users",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns a list of users and permissions" do
      u1 = create(:user)
      u2 = create(:user)

      r1 = create(:repository)
      r2 = create(:repository)
      r3 = create(:repository)

      grant(u1, access_to: r1, as: :user)
      grant(u2, access_to: r1, as: :maintainer)
      grant(u2, access_to: r2, as: :admin)
      grant(u2, access_to: r3, as: :admin)

      # u1 has 1 user, nothing else
      # u2 has 1 maintainer, 2 admin

      @user = create(:user, :admin)
      get "/v1/admin/users",
        headers: authenticated

      # Admin. No permission data.
      admin = response.json[:users].find { _1[:user][:id] == @user.id }
      expect(admin).not_to be_nil
      expect(admin).to have_key(:user)
      expect(admin.dig(:user, :login)).to eq @user.login
      expect(admin).not_to have_key(:permissions)

      user = response.json[:users].find { _1[:user][:id] == u1.id }
      expect(user).not_to be_nil
      expect(user).to have_key(:user)
      expect(user.dig(:user, :login)).to eq u1.login
      expect(user).to have_key(:permissions)
      expect(user[:permissions]).to eq({ "user" => 1, "admin" => 0, "maintainer" => 0 })

      user = response.json[:users].find { _1[:user][:id] == u2.id }
      expect(user).not_to be_nil
      expect(user).to have_key(:user)
      expect(user.dig(:user, :login)).to eq u2.login
      expect(user).to have_key(:permissions)
      expect(user[:permissions]).to eq({ "user" => 0, "admin" => 2, "maintainer" => 1 })
    end

    it "allows searching" do
      create(:user, login: "foobar")
      create(:user, login: "foofoo")
      create(:user, login: "barfoo")

      @user = create(:user, :admin)
      get "/v1/admin/users",
        params: { search: "foo" },
        headers: authenticated

      expect(response).to have_http_status(:ok)
      all_users = response.json[:users].map { _1.dig(:user, :login) }
      expect(all_users).to include("foobar")
      expect(all_users).to include("foofoo")
      expect(all_users).not_to include("barfoo")
    end
  end

  describe "#users_sync_perms" do
    it "returns forbidden for non-admin users" do
      post "/v1/admin/users/1/sync_perms",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 if the user does not exist" do
      @user = create(:user, :admin)
      post "/v1/admin/users/0/sync_perms",
        headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "requests resync for users" do
      @user = create(:user, :admin)
      expect do
        post "/v1/admin/users/#{@user.id}/sync_perms",
          headers: authenticated
      end.to enqueue_job

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "#users_logout" do
    it "returns forbidden for non-admin users" do
      post "/v1/admin/users/1/logout",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 if the user does not exist" do
      @user = create(:user, :admin)
      post "/v1/admin/users/0/logout",
        headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "requests resync for users" do
      @user = create(:user, :admin)

      other = create(:user)
      other.tokens.create(kind: :auth)

      post "/v1/admin/users/#{other.id}/logout",
        headers: authenticated

      expect(response).to have_http_status(:no_content)

      expect(other.tokens.count).to be_zero
    end
  end

  describe "#users_delete" do
    it "returns forbidden for non-admin users" do
      delete "/v1/admin/users/1",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 if user does not exist" do
      @user = create(:user, :admin)
      delete "/v1/admin/users/0",
        headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "deletes a single user" do
      other = create(:user)

      @user = create(:user, :admin)
      delete "/v1/admin/users/#{other.id}",
        headers: authenticated

      expect(response).to have_http_status(:no_content)

      expect(User.find_by(id: other.id)).to be_nil
    end

    it "refuses to delete the current authenticated user" do
      @user = create(:user, :admin)
      delete "/v1/admin/users/#{@user.id}",
        headers: authenticated

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:admin, :cannot_delete_self)
    end
  end

  describe "#users_update_membership" do
    it "returns forbidden for non-admin users" do
      delete "/v1/admin/users/1",
        headers: authenticated
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 if user does not exist" do
      @user = create(:user, :admin)
      delete "/v1/admin/users/0",
        headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "rejects unknown roles" do
      @user = create(:user, :admin)
      patch "/v1/admin/users/#{@user.id}/membership",
        params: { role: :staff },
        headers: authenticated
      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:admin, :unknown_role)
    end

    it "refuses to demote the last admin" do
      @user = create(:user, :admin)
      patch "/v1/admin/users/#{@user.id}/membership",
        params: { role: :user },
        headers: authenticated
      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:admin, :cannot_demote_last_admin)
    end

    it "updates admin to user" do
      @user = create(:user, :admin)
      other = create(:user, :admin)
      patch "/v1/admin/users/#{other.id}/membership",
        params: { role: :user },
        headers: authenticated
      expect(response).to have_http_status(:no_content)
    end

    it "updates user to admin" do
      @user = create(:user, :admin)
      other = create(:user)
      patch "/v1/admin/users/#{other.id}/membership",
        params: { role: :admin },
        headers: authenticated
      expect(response).to have_http_status(:no_content)
    end
  end
end
