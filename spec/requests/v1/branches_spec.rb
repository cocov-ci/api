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
      create(:branch, repository: repo, name: "a_branch")

      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/branches", headers: authenticated
      expect(response).to have_http_status(:ok)

      json = response.json
      expect(json).to have_key :branches
      expect(json[:branches].count).to eq 2

      expect(json[:branches].first).to eq "master"
      expect(json[:branches].last).to eq "a_branch"
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
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/branches/foo", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "gets info about a single branch" do
      branch = create(:branch, :with_repository, :with_commit)
      repo = branch.repository
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/branches/#{branch.name}", headers: authenticated
      expect(response).to have_http_status(:ok)

      json = response.json

      expect(json[:id]).to eq branch.id
      expect(json[:name]).to eq branch.name
      expect(json[:issues]).to be_nil
      expect(json[:coverage]).to be_nil
    end

    it "finds branches containing slashes" do
      branch = create(:branch, :with_repository, :with_commit, name: "feat/foo")
      repo = branch.repository
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/branches/#{branch.name}", headers: authenticated
      expect(response).to have_http_status(:ok)
    end

    it "correctly returns branch data when a head does not have an associated user" do
      branch = create(:branch, :with_repository, :with_commit)
      repo = branch.repository
      @user = create(:user)
      grant(@user, access_to: repo)

      # remove user from commit
      commit = branch.head
      commit.user = nil
      commit.save!

      get "/v1/repositories/#{repo.name}/branches/#{branch.name}", headers: authenticated
      expect(response).to have_http_status(:ok)

      json = response.json

      expect(json[:head]).not_to be_nil
      expect(json.dig(:head, :user)).to be_nil
    end
  end

  describe "#graph (coverage)" do
    let(:today) { "2022-12-28T00:00:00Z" }

    it "returns data" do
      mock_redis!
      r = create(:repository)
      branch = create(:branch, repository: r, name: "feat/foo")
      @user = create(:user)
      grant(@user, access_to: r)

      Timecop.freeze(today) do
        CoverageHistory.create!(repository: r, branch:, percentage: 80, created_at: 10.years.ago)
        get "/v1/repositories/#{r.name}/branches/graphs/#{branch.name}",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json[:issues]).not_to be_empty
        expect(response.json[:issues].values.all?(&:nil?)).to be true
        expect(response.json[:coverage].length).to eq 31
        expect(response.json[:coverage].values).to be_all(80)
      end
    end
  end

  describe "#graphs (issues)" do
    let(:today) { "2022-12-28T00:00:00Z" }

    it "returns data" do
      mock_redis!
      r = create(:repository)
      branch = create(:branch, repository: r, name: "feat/foo")
      @user = create(:user)
      grant(@user, access_to: r)

      Timecop.freeze(today) do
        IssueHistory.create!(repository: r, branch:, quantity: 80, created_at: 10.years.ago)
        get "/v1/repositories/#{r.name}/branches/graphs/#{branch.name}",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json[:coverage]).not_to be_empty
        expect(response.json[:coverage].values.all?(&:nil?)).to be true
        expect(response.json[:issues].length).to eq 31
        expect(response.json[:issues].values).to be_all(80)
      end
    end
  end

  describe "#top_issues" do
    let(:today) { "2022-12-28T00:00:00Z" }

    it "returns data" do
      mock_redis!
      r = create(:repository)
      commit = create(:commit, repository: r)
      branch = create(:branch, repository: r, head: commit, name: "feat/foo")
      @user = create(:user)
      grant(@user, access_to: r)

      Timecop.freeze(today) do
        create(:issue, kind: :security, commit:)
        create(:issue, kind: :security, commit:)
        create(:issue, kind: :convention, commit:)

        get "/v1/repositories/#{r.name}/branches/top_issues/#{branch.name}",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json[:security]).to eq 2
        expect(response.json[:convention]).to eq 1
      end
    end
  end
end
