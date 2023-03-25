# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Cache" do
  describe "#index" do
    it "returns 404 when repository does not exist" do
      get "/v1/repositories/dummy/cache",
        params: { engine: "test" },
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "rejects unknown order" do
      repo = create(:repository)
      get "/v1/repositories/#{repo.id}/cache",
        params: { engine: "test", order: "bla" },
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:cache, :invalid_order)
    end

    describe "with sorting option set" do
      let(:repo) { create(:repository) }
      let(:old_item) { create(:cache_artifact, repository: repo, created_at: 3.weeks.ago) }
      let(:new_item) { create(:cache_artifact, repository: repo) }
      let(:stale_item) { create(:cache_artifact, repository: repo, created_at: 4.weeks.ago, last_used_at: 4.weeks.ago) }

      before do
        [new_item, old_item, stale_item] # ensure to create all items
      end

      it "sorts by creation date by default" do
        get "/v1/repositories/#{repo.id}/cache",
          params: { engine: "test" },
          headers: authenticated(as: :service)
        expect(response).to have_http_status(:ok)
        json = response.json

        expect(json.dig(:repository, :id)).to eq repo.id
        expect(json[:artifacts].length).to eq 3
        expect(json.dig(:artifacts, 0, :name)).to eq new_item.name
        expect(json.dig(:artifacts, 1, :name)).to eq old_item.name
        expect(json.dig(:artifacts, 2, :name)).to eq stale_item.name
      end

      it "sorts by creation date" do
        get "/v1/repositories/#{repo.id}/cache",
          params: { engine: "test", order: "created_at" },
          headers: authenticated(as: :service)
        expect(response).to have_http_status(:ok)
        json = response.json

        expect(json.dig(:repository, :id)).to eq repo.id
        expect(json[:artifacts].length).to eq 3
        expect(json.dig(:artifacts, 0, :name)).to eq new_item.name
        expect(json.dig(:artifacts, 1, :name)).to eq old_item.name
        expect(json.dig(:artifacts, 2, :name)).to eq stale_item.name
      end

      it "sorts by staleness" do
        get "/v1/repositories/#{repo.id}/cache",
          params: { engine: "test", order: "stale" },
          headers: authenticated(as: :service)
        expect(response).to have_http_status(:ok)
        json = response.json

        expect(json.dig(:repository, :id)).to eq repo.id
        expect(json[:artifacts].length).to eq 3
        expect(json.dig(:artifacts, 0, :name)).to eq stale_item.name
        expect(json.dig(:artifacts, 1, :name)).to eq new_item.name
        expect(json.dig(:artifacts, 2, :name)).to eq old_item.name
      end
    end
  end

  describe "#create" do
    let(:repository) { create(:repository) }
    let(:artifact_data) do
      {
        name: "test1",
        name_hash: Digest::SHA1.hexdigest("test1"),
        size: 1024,
        mime: "application/octet-stream",
        engine: "test"
      }
    end

    drop_values = %i[name size mime engine]
    drop_values.each do |key|
      it "rejects requests lacking a #{key} field" do
        post "/v1/repositories/#{repository.id}/cache",
          params: artifact_data.except(key),
          headers: authenticated(as: :service)

        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:cache, "missing_#{key}".to_sym)
      end
    end

    it "creates an artifact entry and updates its repository" do
      post "/v1/repositories/#{repository.id}/cache",
        params: artifact_data,
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      json = response.json
      expect(json[:name]).to eq "test1"
      expect(json[:size]).to eq 1024
      expect(json[:mime]).to eq "application/octet-stream"
      expect(repository.reload.cache_size).to eq 1024
    end
  end

  describe "#show" do
    it "shows an item" do
      repo = create(:repository)
      arti = create(:cache_artifact, repository: repo)
      get "/v1/repositories/#{repo.id}/cache/#{arti.name_hash}/meta",
        params: { engine: "test" },
        headers: authenticated(as: :service)
      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({
        "id" => arti.id,
        "name" => arti.name,
        "name_hash" => arti.name_hash,
        "size" => arti.size,
        "engine" => arti.engine,
        "mime" => arti.mime,
        "created_at" => arti.created_at.iso8601,
        "last_used_at" => arti.created_at.iso8601
      })
    end
  end

  describe "#delete" do
    it "deletes an item" do
      repo = create(:repository)
      arti = create(:cache_artifact, repository: repo)
      delete "/v1/repositories/#{repo.id}/cache/#{arti.name_hash}",
        params: { engine: "test" },
        headers: authenticated(as: :service)
      expect(response).to have_http_status(:no_content)
      expect(repo.reload.cache_size).to eq 0
    end
  end

  describe "#touch" do
    it "updates a given item's last_used_at" do
      repo = nil
      arti = nil
      Timecop.freeze do
        repo = create(:repository)
        arti = create(:cache_artifact, repository: repo)
      end

      expect(arti.last_used_at).to be_within(0.1).of arti.created_at

      Timecop.travel(1.hour.from_now) do
        patch "/v1/repositories/#{repo.id}/cache/#{arti.name_hash}/touch",
          params: { engine: "test" },
          headers: authenticated(as: :service)
        expect(response).to have_http_status(:no_content)
        arti.reload
        expect(arti.last_used_at).not_to eq arti.created_at
      end
    end
  end
end
