# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Secrets" do
  before { stub_crypto_key! }

  describe "#index" do
    describe "organization-scoped" do
      it "lists secrets" do
        sec = create(:secret)
        repo = create(:repository)
        create(:secret, repository: repo, scope: :repository)

        get "/v1/secrets", headers: authenticated
        expect(response).to have_http_status(:ok)
        json = response.json
        expect(json[:secrets].length).to eq 1
        expect(json[:secrets].first).to eq({
          "id" => sec.id,
          "name" => sec.name,
          "scope" => sec.scope.to_s,
          "created_at" => sec.created_at.iso8601
        })
      end
    end

    describe "repository-scoped" do
      it "lists secrets" do
        create(:secret)
        repo = create(:repository)
        repo_sec = create(:secret, repository: repo, scope: :repository)

        get "/v1/repositories/#{repo.name}/secrets", headers: authenticated
        json = response.json
        expect(json[:secrets].length).to eq 1
        expect(json[:secrets].first).to eq({
          "id" => repo_sec.id,
          "name" => repo_sec.name,
          "scope" => repo_sec.scope.to_s,
          "created_at" => repo_sec.created_at.iso8601
        })
      end

      it "returns 404 in case a repo does not exist" do
        get "/v1/repositories/bla/secrets", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "#create" do
    describe "organization-scoped" do
      it "validates names" do
        post "/v1/secrets",
          params: { data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :missing_name)
      end

      it "validates data" do
        post "/v1/secrets",
          params: { name: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :missing_data)
      end

      it "validates uniqueness" do
        sec = create(:secret)
        post "/v1/secrets",
          params: { name: sec.name, data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :name_taken)
      end

      it "creates items" do
        post "/v1/secrets",
          params: { name: "bar", data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:created)
        json = response.json
        item = Secret.last
        expect(json[:id]).to eq item.id
        expect(json[:name]).to eq item.name
        expect(json[:scope]).to eq item.scope.to_s
        expect(json[:created_at]).to eq item.created_at.iso8601
      end
    end

    describe "repository-scoped" do
      it "validates names" do
        repo = create(:repository)
        post "/v1/repositories/#{repo.name}/secrets",
          params: { data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :missing_name)
      end

      it "validates data" do
        repo = create(:repository)
        post "/v1/repositories/#{repo.name}/secrets",
          params: { name: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :missing_data)
      end

      it "validates uniqueness" do
        repo = create(:repository)
        sec = create(:secret, repository: repo, scope: :repository)
        post "/v1/repositories/#{repo.name}/secrets",
          params: { name: sec.name, data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :name_taken)
      end

      it "creates items" do
        repo = create(:repository)
        post "/v1/repositories/#{repo.name}/secrets",
          params: { name: "bar", data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:created)
        json = response.json
        item = Secret.last
        expect(json[:id]).to eq item.id
        expect(json[:name]).to eq item.name
        expect(json[:scope]).to eq item.scope.to_s
        expect(json[:created_at]).to eq item.created_at.iso8601
      end
    end
  end

  describe "#patch" do
    describe "organization-scoped" do
      let(:item) { create(:secret) }

      it "validates data" do
        patch "/v1/secrets/#{item.id}",
          params: {},
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :missing_data)
      end

      it "returns 404 in case the item does not exist" do
        patch "/v1/secrets/lol",
          params: { data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item is not organization-scoped" do
        repo = create(:repository)
        item = create(:secret, repository: repo, scope: :repository)
        patch "/v1/secrets/#{item.id}",
          params: { data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "updates items" do
        patch "/v1/secrets/#{item.id}",
          params: { data: "hello" },
          headers: authenticated
        expect(response).to have_http_status(:ok)
        expect(response.json).to eq({
          "id" => item.id,
          "name" => item.name,
          "scope" => item.scope.to_s,
          "created_at" => item.created_at.iso8601
        })

        item.reload
        expect(item.data).to eq "hello"
      end
    end

    describe "repository-scoped" do
      let(:repo) { create(:repository) }
      let(:item) { create(:secret, repository: repo, scope: :repository) }

      it "validates data" do
        patch "/v1/repositories/#{repo.name}/secrets/#{item.id}",
          params: {},
          headers: authenticated
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:secrets, :missing_data)
      end

      it "returns 404 in case the repository does not exist" do
        patch "/v1/repositories/bla/secrets/#{item.id}",
          params: { data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item does not exist" do
        patch "/v1/repositories/#{repo.name}/secrets/bla",
          params: { data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item is not repository-scoped" do
        secret = create(:secret)
        patch "/v1/repositories/#{repo.name}/secrets/#{secret.id}",
          params: { data: "foo" },
          headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "updates items" do
        patch "/v1/repositories/#{repo.name}/secrets/#{item.id}",
          params: { data: "hello" },
          headers: authenticated
        expect(response).to have_http_status(:ok)
        expect(response.json).to eq({
          "id" => item.id,
          "name" => item.name,
          "scope" => item.scope.to_s,
          "created_at" => item.created_at.iso8601
        })

        item.reload
        expect(item.data).to eq "hello"
      end
    end
  end

  describe "#delete" do
    describe "organization-scoped" do
      it "returns 404 in case the item does not exist" do
        delete "/v1/secrets/bla", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item is not organization-scoped" do
        repo = create(:repository)
        item = create(:secret, repository: repo, scope: :repository)
        delete "/v1/secrets/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "deletes items" do
        item = create(:secret)
        delete "/v1/secrets/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:no_content)
        expect(Secret.where(id: item.id)).not_to be_exists
      end
    end

    describe "repository-scoped" do
      it "returns 404 in case the repository does not exist" do
        delete "/v1/repositories/bla/secrets/3", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item does not exist" do
        repo = create(:repository)
        delete "/v1/repositories/#{repo.name}/secrets/bla", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item is not repository-scoped" do
        repo = create(:repository)
        item = create(:secret)
        delete "/v1/repositories/#{repo.name}/secrets/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "deletes items" do
        repo = create(:repository)
        item = create(:secret, repository: repo, scope: :repository)
        delete "/v1/repositories/#{repo.name}/secrets/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:no_content)
        expect(Secret.where(id: item.id)).not_to be_exists
      end
    end
  end
end
