# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Repositories" do
  describe "#index" do
    it "returns a list of repositories" do
      repo = create(:repository, name: "a")
      create(:repository)
      repo.branches.create! name: "master", issues: 2, coverage: 90

      get "/v1/repositories", params: { per_page: 1 }, headers: authenticated
      expect(response).to have_http_status :ok
      json = response.json

      r_repo = json.dig("repositories", 0)
      expect(r_repo[:id]).to eq repo.id
      expect(r_repo[:name]).to eq repo.name
      expect(r_repo[:token]).to eq repo.token
      expect(r_repo[:coverage]).to eq 90
      expect(r_repo[:issues]).to eq 2
    end
  end

  describe "#create" do
    it "returns an error in case the repository already exists" do
      repo = create(:repository)
      post "/v1/repositories", params: { name: repo.name }, headers: authenticated

      expect(response).to have_http_status :conflict
      expect(response).to be_a_json_error :repositories, :already_exists
    end

    it "returns an error in case the repository does not exist on GitHub" do
      stub_configuration!
      gh_app = double(:github)
      expect(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:repo)
        .with("#{@github_organization_name}/foobar")
        .and_raise(Octokit::NotFound)

      post "/v1/repositories", params: { name: "foobar" }, headers: authenticated

      expect(response).to have_http_status :not_found
      expect(response).to be_a_json_error :repositories, :not_on_github
    end

    it "returns the newly created repository on success" do
      stub_configuration!
      gh_app = double(:github)
      expect(Cocov::GitHub).to receive(:app).and_return(gh_app)
      repo = double(:repo)
      expect(repo).to receive(:name).and_return("foobar")
      expect(repo).to receive(:default_branch).and_return("master")
      expect(repo).to receive(:description).and_return("foos the bar")
      expect(gh_app).to receive(:repo).with("#{@github_organization_name}/foobar").and_return(repo)

      post "/v1/repositories", params: { name: "foobar" }, headers: authenticated

      expect(response).to have_http_status :created

      repo = Repository.last
      json = response.json
      expect(json[:name]).to eq "foobar"
      expect(json[:id]).to eq repo.id
      expect(json[:token]).to eq repo.token
    end
  end

  describe "#show" do
    it "returns 404 in case the repository does not exist" do
      get "/v1/repositories/dummy", headers: authenticated

      expect(response).to have_http_status :not_found
      expect(response).to be_a_json_error :not_found
    end

    it "omits branch information when it is absent" do
      repo = create(:repository)
      get "/v1/repositories/#{repo.name}", headers: authenticated

      expect(response).to have_http_status :ok
      json = response.json
      expect(json[:id]).to eq repo.id
      expect(json[:name]).to eq repo.name
      expect(json[:token]).to eq repo.token
      expect(json).not_to have_key :head
    end

    context "with branch" do
      it "includes coverage percentage and a count of issues" do
        branch = create(:branch, :with_repository)
        repo = branch.repository

        get "/v1/repositories/#{repo.name}", headers: authenticated
        expect(response).to have_http_status :ok
        json = response.json
        expect(json[:coverage]).to eq branch.coverage
        expect(json[:issues]).to eq branch.issues
      end

      it "omits head information when it is absent" do
        branch = create(:branch, :with_repository)
        repo = branch.repository

        get "/v1/repositories/#{repo.name}", headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json).not_to have_key :head
      end

      it "shows commit information when head is present" do
        cov = create(:coverage_info, :with_commit, :with_file)
        repo = cov.commit.repository
        repo.branches.create(name: "master", head: cov.commit)
        cov.commit.coverage_processed!
        cov.commit.checks_processed!

        get "/v1/repositories/#{repo.name}", headers: authenticated
        expect(response).to have_http_status :ok
        json = response.json
        expect(json).to have_key :head
        expect(json.dig(:head, :checks_status)).to eq "processed"
        expect(json.dig(:head, :coverage_status)).to eq "processed"
        expect(json.dig(:head, :files_count)).to eq 1
      end
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
        get "/v1/repositories/#{r.name}/graph/coverage",
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
        get "/v1/repositories/#{r.name}/graph/issues",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json.length).to eq 31
        expect(response.json.all? { _1 == 80 }).to be true
      end
    end
  end

  describe "#stats_coverage" do
    let(:repo) { create(:repository) }
    let(:branch) { create(:branch, repository: repo) }

    let(:today) { "2022-12-28T00:00:00Z" }

    it "requires 'from'" do
      get "/v1/repositories/#{repo.name}/stats/coverage",
        params: { to: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :missing_from_date
    end

    it "requires 'to'" do
      get "/v1/repositories/#{repo.name}/stats/coverage",
        params: { from: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :missing_to_date
    end

    it "validates 'from'" do
      get "/v1/repositories/#{repo.name}/stats/coverage",
        params: { from: "invalid", to: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :invalid_from_date
    end

    it "validates 'to'" do
      get "/v1/repositories/#{repo.name}/stats/coverage",
        params: { from: "2022-12-28", to: "invalid" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :invalid_to_date
    end

    it "does not allow more than 100 days" do
      get "/v1/repositories/#{repo.name}/stats/coverage",
        params: { from: "2012-12-28", to: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :stats_range_too_large
    end

    it "returns data" do
      CoverageHistory.create!(repository: repo, branch:, percentage: 80, created_at: 10.years.ago)
      Timecop.freeze(today) do
        get "/v1/repositories/#{repo.name}/stats/coverage",
          params: { from: 1.day.ago.iso8601, to: 1.day.ago.iso8601 },
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json.length).to eq 1
        expect(response.json.first[:date]).to eq 1.day.ago.to_date.iso8601
        expect(response.json.first[:value]).to eq 80
      end
    end
  end

  describe "#stats_issues" do
    let(:repo) { create(:repository) }
    let(:branch) { create(:branch, repository: repo) }
    let(:today) { "2022-12-28T00:00:00Z" }

    it "requires 'from'" do
      get "/v1/repositories/#{repo.name}/stats/issues",
        params: { to: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :missing_from_date
    end

    it "requires 'to'" do
      get "/v1/repositories/#{repo.name}/stats/issues",
        params: { from: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :missing_to_date
    end

    it "validates 'from'" do
      get "/v1/repositories/#{repo.name}/stats/issues",
        params: { from: "invalid", to: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :invalid_from_date
    end

    it "validates 'to'" do
      get "/v1/repositories/#{repo.name}/stats/issues",
        params: { from: "2022-12-28", to: "invalid" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :invalid_to_date
    end

    it "does not allow more than 100 days" do
      get "/v1/repositories/#{repo.name}/stats/issues",
        params: { from: "2012-12-28", to: "2022-12-28" },
        headers: authenticated

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :repositories, :stats_range_too_large
    end

    it "returns data" do
      IssueHistory.create!(repository: repo, branch:, quantity: 80, created_at: 10.years.ago)
      Timecop.freeze(today) do
        get "/v1/repositories/#{repo.name}/stats/issues",
          params: { from: 1.day.ago.iso8601, to: 1.day.ago.iso8601 },
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json.length).to eq 1
        expect(response.json.first[:date]).to eq 1.day.ago.to_date.iso8601
        expect(response.json.first[:value]).to eq 80
      end
    end
  end

  describe "#search" do
    it "returns results based on fuzzy search" do
      %w[api api-helper apiarist].each do |n|
        create(:repository, name: n)
      end

      get "/v1/repositories/$search",
        params: { term: "api" },
        headers: authenticated
      expect(response).to have_http_status :ok
      expect(response.json.length).to eq 3
      expect(response.json[0][:name]).to eq "api"
      expect(response.json[1][:name]).to eq "api-helper"
      expect(response.json[2][:name]).to eq "apiarist"
    end
  end
end
