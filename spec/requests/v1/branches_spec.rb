# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Branches" do
  describe "#index" do
    it "returns 404 when repository does not exist" do
      get "/v1/repositories/dummy/branches", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "lists branches" do
      branch = create(:branch, :with_repository, :with_commit)
      repo = branch.repository

      get "/v1/repositories/#{repo.name}/branches", headers: authenticated
      expect(response).to have_http_status(:ok)

      json = response.json
      expect(json).to have_key :branches
      expect(json[:branches].count).to eq 1

      json_bra = json.dig(:branches, 0)
      expect(json_bra[:id]).to eq branch.id
      expect(json_bra[:name]).to eq branch.name
      expect(json_bra[:issues]).to be_nil
      expect(json_bra[:coverage]).to be_nil
    end
  end

  describe "#show" do
    it "returns 404 when repository does not exist" do
      get "/v1/repositories/dummy/branches/foo", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 when branch does not exist" do
      repo = create(:repository)
      get "/v1/repositories/#{repo.name}/branches/foo", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "gets info about a single branch" do
      branch = create(:branch, :with_repository, :with_commit)
      repo = branch.repository

      get "/v1/repositories/#{repo.name}/branches/#{branch.name}", headers: authenticated
      expect(response).to have_http_status(:ok)

      json = response.json

      expect(json[:id]).to eq branch.id
      expect(json[:name]).to eq branch.name
      expect(json[:issues]).to be_nil
      expect(json[:coverage]).to be_nil
    end
  end

  describe "#graph_coverage" do
    let(:today) { "2022-12-28T00:00:00Z" }

    it "returns data" do
      mock_redis!
      r = create(:repository)
      branch = create(:branch, repository: r)

      Timecop.freeze(today) do
        CoverageHistory.create!(repository: r, branch:, percentage: 80, created_at: 10.years.ago)
        get "/v1/repositories/#{r.name}/branches/#{branch.name}/graph/coverage",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json.length).to eq 31
        expect(response.json.all? { _1 == 80 }).to be true
      end
    end
  end

  describe "#graph_issues" do
    let(:today) { "2022-12-28T00:00:00Z" }

    it "returns data" do
      mock_redis!
      r = create(:repository)
      branch = create(:branch, repository: r)

      Timecop.freeze(today) do
        IssueHistory.create!(repository: r, branch:, quantity: 80, created_at: 10.years.ago)
        get "/v1/repositories/#{r.name}/branches/#{branch.name}/graph/issues",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json.length).to eq 31
        expect(response.json.all? { _1 == 80 }).to be true
      end
    end
  end
end
