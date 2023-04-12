# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::RepositoryCacheSettings" do
  describe "#index" do
    it "returns 404 when repository does not exist" do
      get "/v1/repositories/dummy/settings/cache", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "indicates in case cache is disabled" do
      with_caching_disabled
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/settings/cache", headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json).to have_key :enabled
      expect(response.json[:enabled]).to be false
    end

    it "returns an empty array when repository has no artifacts" do
      with_caching_enabled
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/settings/cache", headers: authenticated
      expect(response).to have_http_status(:ok)
      json = response.json
      expect(json[:enabled]).to be true
      expect(json[:storage_used]).to be_zero
      expect(json[:storage_limit]).to be_zero
      expect(json[:artifacts].length).to be_zero
    end

    it "returns artifacts with usage information" do
      with_caching_enabled(max_size: 1024 * 1024)
      repo = create(:repository)
      artifact = create(:cache_artifact,
        repository: repo,
        size: 524_288,
        last_used_at: nil)
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/settings/cache", headers: authenticated
      expect(response).to have_http_status(:ok)
      json = response.json
      expect(json[:enabled]).to be true
      expect(json[:storage_used]).to eq 524_288
      expect(json[:storage_limit]).to eq 1024 * 1024
      expect(json[:artifacts].length).to eq 1

      art = json[:artifacts].first
      expect(art[:id]).to eq artifact.id
      expect(art[:name]).to eq artifact.name
      expect(art[:created_at]).to eq artifact.created_at.iso8601
      expect(art[:last_used_at]).to be_nil
    end
  end

  describe "#delete" do
    it "returns an error if cache is disabled" do
      with_caching_disabled
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      delete "/v1/repositories/#{repo.name}/settings/cache/1", headers: authenticated
      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:cache_settings, :cache_disabled)
    end

    it "returns 404 in case repository does not exist" do
      with_caching_enabled

      delete "/v1/repositories/foo/settings/cache/1", headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 in case artifact does not exist" do
      with_caching_enabled
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      delete "/v1/repositories/#{repo.name}/settings/cache/1", headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "requests cache eviction" do
      mock_redis!

      with_caching_enabled(max_size: 1024 * 1024)
      repo = create(:repository)
      artifact = create(:cache_artifact,
        repository: repo,
        size: 524_288,
        last_used_at: nil)
      @user = create(:user)
      grant(@user, access_to: repo)

      delete "/v1/repositories/#{repo.name}/settings/cache/#{artifact.id}", headers: authenticated
      expect(response).to have_http_status(:no_content)

      queue = "cocov:cached:housekeeping_tasks"
      expect(@redis.llen(queue)).to eq 1
      data = JSON.parse(@redis.lpop(queue), symbolize_names: true)

      expect(data[:task]).to eq "evict-artifact"
      expect(data[:repository]).to eq repo.id
      expect(data[:objects]).to eq [artifact.id]
    end
  end

  describe "#purge" do
    it "returns an error if cache is disabled" do
      with_caching_disabled
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      post "/v1/repositories/#{repo.name}/settings/cache/purge", headers: authenticated
      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:cache_settings, :cache_disabled)
    end

    it "returns 404 in case repository does not exist" do
      with_caching_enabled

      post "/v1/repositories/foo/settings/cache/purge", headers: authenticated
      expect(response).to have_http_status(:not_found)
    end

    it "requests cache eviction" do
      mock_redis!

      with_caching_enabled(max_size: 1024 * 1024)
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      post "/v1/repositories/#{repo.name}/settings/cache/purge", headers: authenticated
      expect(response).to have_http_status(:no_content)

      queue = "cocov:cached:housekeeping_tasks"
      expect(@redis.llen(queue)).to eq 1
      data = JSON.parse(@redis.lpop(queue), symbolize_names: true)

      expect(data[:task]).to eq "purge-repository"
      expect(data[:repository]).to eq repo.id
    end
  end
end
