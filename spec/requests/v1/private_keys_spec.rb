# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::PrivateKeys" do
  before { stub_crypto_key! }

  describe "#index" do
    describe "organization-scoped" do
      it "lists private_keys" do
        sec = create(:private_key)
        repo = create(:repository)
        create(:private_key, repository: repo, scope: :repository)

        get "/v1/private_keys", headers: authenticated
        expect(response).to have_http_status(:ok)
        json = response.json
        expect(json[:private_keys].length).to eq 1
        expect(json[:private_keys].first).to eq({
          "id" => sec.id,
          "name" => sec.name,
          "scope" => sec.scope.to_s,
          "digest" => sec.digest,
          "created_at" => sec.created_at.iso8601
        })
      end
    end

    describe "repository-scoped" do
      it "lists private_keys" do
        create(:private_key)
        repo = create(:repository)
        repo_key = create(:private_key, repository: repo, scope: :repository)

        get "/v1/repositories/#{repo.name}/private_keys", headers: authenticated
        json = response.json
        expect(json[:private_keys].length).to eq 1
        expect(json[:private_keys].first).to eq({
          "id" => repo_key.id,
          "name" => repo_key.name,
          "scope" => repo_key.scope.to_s,
          "digest" => repo_key.digest,
          "created_at" => repo_key.created_at.iso8601
        })
      end

      it "returns 404 in case a repo does not exist" do
        get "/v1/repositories/bla/private_keys", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "#create" do
    let(:valid_key) { fixture_file("ssh_key") }

    describe "organization-scoped" do
      it "validates name" do
        post "/v1/private_keys",
          headers: authenticated,
          params: { key: valid_key }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :missing_name)
      end

      it "validates key presence" do
        post "/v1/private_keys",
          headers: authenticated,
          params: { name: "test" }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :missing_key)
      end

      it "validates key consistency" do
        post "/v1/private_keys",
          headers: authenticated,
          params: { name: "test", key: "invalid" }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :invalid_key)
      end

      it "validates uniqueness" do
        key = create(:private_key)
        post "/v1/private_keys",
          headers: authenticated,
          params: { name: key.name, key: valid_key }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :name_taken)
      end

      it "creates keys" do
        post "/v1/private_keys",
          headers: authenticated,
          params: { name: "test", key: valid_key }
        expect(response).to have_http_status(:created)
        k = PrivateKey.last
        expect(response.json).to eq({
          "id" => k.id,
          "name" => k.name,
          "digest" => k.digest,
          "scope" => k.scope.to_s,
          "created_at" => k.created_at.iso8601
        })
      end
    end

    describe "repository-scoped" do
      let(:repo) { create(:repository) }

      it "returns 404 in case a repo does not exist" do
        post "/v1/repositories/bla/private_keys",
          headers: authenticated,
          params: { name: "test", key: valid_key }
        expect(response).to have_http_status(:not_found)
      end

      it "validates name" do
        post "/v1/repositories/#{repo.name}/private_keys",
          headers: authenticated,
          params: { key: valid_key }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :missing_name)
      end

      it "validates key presence" do
        post "/v1/repositories/#{repo.name}/private_keys",
          headers: authenticated,
          params: { name: "test" }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :missing_key)
      end

      it "validates key consistency" do
        post "/v1/repositories/#{repo.name}/private_keys",
          headers: authenticated,
          params: { name: "test", key: "invalid" }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :invalid_key)
      end

      it "validates uniqueness" do
        k = create(:private_key, scope: :repository, repository: repo)

        post "/v1/repositories/#{repo.name}/private_keys",
          headers: authenticated,
          params: { name: k.name, key: valid_key }
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:private_keys, :name_taken)
      end

      it "creates keys" do
        post "/v1/repositories/#{repo.name}/private_keys",
          headers: authenticated,
          params: { name: "test", key: valid_key }

        expect(response).to have_http_status(:created)
        k = PrivateKey.last
        expect(response.json).to eq({
          "id" => k.id,
          "name" => k.name,
          "digest" => k.digest,
          "scope" => k.scope.to_s,
          "created_at" => k.created_at.iso8601
        })
      end
    end
  end

  describe "#delete" do
    describe "organization-scoped" do
      it "returns 404 in case the item does not exist" do
        delete "/v1/private_keys/bla", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item is not organization-scoped" do
        repo = create(:repository)
        item = create(:private_key, repository: repo, scope: :repository)
        delete "/v1/private_keys/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "deletes items" do
        item = create(:private_key)
        delete "/v1/private_keys/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:no_content)
        expect(PrivateKey.where(id: item.id)).not_to be_exists
      end
    end

    describe "repository-scoped" do
      it "returns 404 in case the repository does not exist" do
        delete "/v1/repositories/bla/private_keys/3", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item does not exist" do
        repo = create(:repository)
        delete "/v1/repositories/#{repo.name}/private_keys/bla", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 in case the item is not repository-scoped" do
        repo = create(:repository)
        item = create(:private_key)
        delete "/v1/repositories/#{repo.name}/private_keys/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:not_found)
      end

      it "deletes items" do
        repo = create(:repository)
        item = create(:private_key, repository: repo, scope: :repository)
        delete "/v1/repositories/#{repo.name}/private_keys/#{item.id}", headers: authenticated
        expect(response).to have_http_status(:no_content)
        expect(Secret.where(id: item.id)).not_to be_exists
      end
    end
  end
end
