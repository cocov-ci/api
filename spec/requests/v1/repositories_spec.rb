# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Repositories" do
  describe "#index" do
    it "returns a list of repositories" do
      repo = create(:repository, name: "a")
      create(:repository)
      repo.branches.create! name: "master", issues: 2, coverage: 90

      @user = create(:user)
      grant(@user, access_to: repo)

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

    it "correctly counts active issues" do
      issue = create(:issue, :with_commit)
      commit = issue.commit
      repo = commit.repository
      branch = repo.branches.create! name: "master", issues: 1, coverage: 90
      branch.head = commit
      branch.save!

      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories", params: { per_page: 1 }, headers: authenticated
      expect(response).to have_http_status :ok
      json = response.json

      r_repo = json.dig("repositories", 0)
      expect(r_repo[:issues]).to eq 1

      issue.ignore!(user: @user, reason: nil)

      get "/v1/repositories", params: { per_page: 1 }, headers: authenticated
      expect(response).to have_http_status(:ok)
      json = response.json

      r_repo = json.dig("repositories", 0)
      expect(r_repo[:issues]).to eq 0
    end
  end

  describe "#create" do
    it "returns an error in case the repository already exists" do
      stub_configuration!
      gh_app = double(:github)
      expect(Cocov::GitHub).to receive(:app).and_return(gh_app)
      fake_repo = double(:repo)
      expect(gh_app).to receive(:repo)
        .with("#{@github_organization_name}/foobar")
        .and_return(fake_repo)

      repo = create(:repository)
      expect(fake_repo).to receive(:id).and_return(repo.github_id)
      post "/v1/repositories", params: { name: "foobar" }, headers: authenticated

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
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      repo = double(:repo)
      allow(repo).to receive_messages(name: "foobar", default_branch: "master", description: "foos the bar", id: 10_000)
      expect(gh_app).to receive(:repo).with("#{@github_organization_name}/foobar").and_return(repo)

      post "/v1/repositories", params: { name: "foobar" }, headers: authenticated

      expect(response).to have_http_status :created

      repo = Repository.last
      json = response.json
      expect(json[:name]).to eq "foobar"
      expect(json[:id]).to eq repo.id
      expect(json[:token]).to eq repo.token

      expect(UpdateRepoPermissionsJob).to have_been_enqueued.exactly(:once).with(repo.id)
      expect(InitializeRepositoryJob).to have_been_enqueued.exactly(:once).with(repo.id)
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
      @user = create(:user)
      grant(@user, access_to: repo)

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
        @user = create(:user)
        grant(@user, access_to: repo)

        get "/v1/repositories/#{repo.name}", headers: authenticated
        expect(response).to have_http_status :ok
        json = response.json
        expect(json[:coverage]).to eq branch.coverage
        expect(json[:issues]).to eq branch.issues
      end

      it "omits head information when it is absent" do
        branch = create(:branch, :with_repository)
        repo = branch.repository
        @user = create(:user)
        grant(@user, access_to: repo)

        get "/v1/repositories/#{repo.name}", headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json).not_to have_key :head
      end

      it "shows commit information when head is present" do
        cov = create(:coverage_info, :with_commit, :with_file, status: :completed)
        repo = cov.commit.repository
        repo.branches.create(name: "master", head: cov.commit)
        cov.commit.reset_check_set!
        cov.commit.check_set.completed!
        @user = create(:user)
        grant(@user, access_to: repo)

        get "/v1/repositories/#{repo.name}", headers: authenticated
        expect(response).to have_http_status :ok
        json = response.json
        expect(json).to have_key :head
        expect(json.dig(:head, :checks_status)).to eq "completed"
        expect(json.dig(:head, :coverage_status)).to eq "completed"
        expect(json.dig(:head, :files_count)).to eq 1
      end
    end
  end

  describe "#graphs (coverage)" do
    let(:today) { "2022-12-28T00:00:00Z" }

    it "returns data" do
      mock_redis!
      r = create(:repository)
      branch = create(:branch, repository: r)
      @user = create(:user)
      grant(@user, access_to: r)

      Timecop.freeze(today) do
        CoverageHistory.create!(repository: r, branch:, percentage: 80, created_at: 10.years.ago)
        get "/v1/repositories/#{r.name}/graphs",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json[:issues].values.compact).to be_empty
        expect(response.json[:coverage].length).to eq 31
        expect(response.json[:coverage].values).to be_all(80)
      end
    end

    it "indicates when no data is available" do
      mock_redis!
      r = create(:repository)
      create(:branch, repository: r)
      @user = create(:user)
      grant(@user, access_to: r)

      Timecop.freeze(today) do
        get "/v1/repositories/#{r.name}/graphs",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json[:issues].values.compact).to be_empty
        expect(response.json[:coverage].values.compact).to be_empty
      end
    end
  end

  describe "#graphs (issues)" do
    let(:today) { "2022-12-28T00:00:00Z" }

    it "returns data" do
      mock_redis!
      r = create(:repository)
      branch = create(:branch, repository: r)
      @user = create(:user)
      grant(@user, access_to: r)

      Timecop.freeze(today) do
        IssueHistory.create!(repository: r, branch:, quantity: 80, created_at: 10.years.ago)
        get "/v1/repositories/#{r.name}/graphs",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json[:coverage]).not_to be_empty
        expect(response.json[:coverage].values.all?(&:nil?)).to be true
        expect(response.json[:issues].length).to eq 31
        expect(response.json[:issues].values).to be_all(80)
      end
    end

    it "indicates when no data is available" do
      mock_redis!
      r = create(:repository)
      create(:branch, repository: r)
      @user = create(:user)
      grant(@user, access_to: r)

      Timecop.freeze(today) do
        get "/v1/repositories/#{r.name}/graphs",
          headers: authenticated
        expect(response).to have_http_status :ok
        expect(response.json[:coverage].compact).to be_empty
        expect(response.json[:issues].values.compact).to be_empty
      end
    end
  end

  describe "#stats_coverage" do
    let(:repo) { create(:repository) }
    let(:branch) { create(:branch, repository: repo) }
    let(:today) { "2022-12-28T00:00:00Z" }

    before do
      @user = create(:user)
      grant(@user, access_to: repo)
    end

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

    before do
      @user = create(:user)
      grant(@user, access_to: repo)
    end

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
      @user = create(:user)
      %w[api api-helper apiarist].each do |n|
        repo = create(:repository, name: n)
        grant(@user, access_to: repo)
      end

      get "/v1/repositories",
        params: { search_term: "api" },
        headers: authenticated
      expect(response).to have_http_status :ok
      expect(response.json[:repositories].length).to eq 3
      expect(response.json[:repositories][0][:name]).to eq "api"
      expect(response.json[:repositories][1][:name]).to eq "api-helper"
      expect(response.json[:repositories][2][:name]).to eq "apiarist"
    end
  end

  describe "#update_org_repos" do
    it "enqueues a new UpdateOrganizationReposJob" do
      call = lambda do
        post "/v1/repositories/$org_repos/update",
          headers: authenticated
        expect(response).to have_http_status(:no_content)
      end

      expect(call).to have_enqueued_job
    end
  end

  describe "#org_repos" do
    context "when cache is empty" do
      before do
        mock_redis!
        bypass_redlock!
      end

      it "sets the global state as updating and enqueues a new job" do
        call = lambda do
          get "/v1/repositories/$org_repos",
            headers: authenticated

          expect(response).to have_http_status(:ok)
          expect(response.json[:status]).to eq "updating"
        end

        expect(call).to have_enqueued_job
        expect(@cache.get("cocov:github_org_repos:status")).to eq "updating"
      end
    end

    context "when an update is in progress" do
      before do
        mock_redis!
        bypass_redlock!
      end

      it "returns the correct status without enqueuing a job" do
        @cache.set("cocov:github_org_repos:status", "updating")

        call = lambda do
          get "/v1/repositories/$org_repos",
            headers: authenticated

          expect(response).to have_http_status(:ok)
          expect(response.json[:status]).to eq "updating"
        end

        expect(call).not_to have_enqueued_job
      end
    end

    context "when data is available" do
      before do
        mock_redis!
        bypass_redlock!
        stub_const("V1::RepositoriesController::REPOSITORIES_PER_PAGE", 5)
        @cache.set("cocov:github_org_repos:status", "present")
        @cache.set("cocov:github_org_repos:items", repos.to_json)
        @cache.set("cocov:github_org_repos:etag", "lolsies")
        @cache.set("cocov:github_org_repos:updated_at", Time.now.iso8601)
      end

      let(:repos) do
        now = 10.hours.ago
        (0...10).to_a.map do |i|
          {
            id: i,
            name: "repo_#{i}",
            created_at: now,
            pushed_at: now,
            description: "Something"
          }.tap { now += 1.hour }
        end
      end

      it "returns the correct status without enqueuing a job" do
        create(:repository, github_id: 1)

        call = lambda do
          get "/v1/repositories/$org_repos",
            headers: authenticated
          expect(response).to have_http_status(:ok)
          expect(response.json[:status]).to eq "ok"
          expect(response.json[:items].length).to eq 5
          expect(response.json[:items].first[:name]).to eq "repo_0"
          # repo_1 is present
          expect(response.json[:items].second[:status]).to eq "present"

          expect(response.json[:items].last[:name]).to eq "repo_4"
          expect(response.json[:items].last[:status]).to eq "absent"
          expect(response.json[:total_pages]).to eq 2
          expect(response.json[:current_page]).to eq 1
          expect(response.json[:next_page]).to eq "http://www.example.com/v1/repositories/$org_repos?page=2"
          expect(response.json[:prev_page]).to be_nil
        end

        expect(call).not_to have_enqueued_job
      end

      it "returns the second page" do
        call = lambda do
          get "/v1/repositories/$org_repos",
            params: { page: "2" },
            headers: authenticated

          expect(response).to have_http_status(:ok)
          expect(response.json[:status]).to eq "ok"
          expect(response.json[:items].length).to eq 5
          expect(response.json[:items].first[:name]).to eq "repo_5"
          expect(response.json[:items].last[:name]).to eq "repo_9"
          expect(response.json[:total_pages]).to eq 2
          expect(response.json[:current_page]).to eq 2
          expect(response.json[:prev_page]).to eq "http://www.example.com/v1/repositories/$org_repos?page=1"
          expect(response.json[:next_page]).to be_nil
        end

        expect(call).not_to have_enqueued_job
      end

      it "searches data (no results)" do
        call = lambda do
          get "/v1/repositories/$org_repos",
            params: { search_term: "bla" },
            headers: authenticated

          expect(response).to have_http_status(:ok)
          expect(response.json[:status]).to eq "ok"
          expect(response.json[:items].length).to eq 0
          expect(response.json[:total_pages]).to eq 0
          expect(response.json[:current_page]).to eq 1
          expect(response.json[:prev_page]).to be_nil
          expect(response.json[:next_page]).to be_nil
        end

        expect(call).not_to have_enqueued_job
      end

      it "searches data" do
        call = lambda do
          get "/v1/repositories/$org_repos",
            params: { search_term: "rep 2" },
            headers: authenticated

          expect(response).to have_http_status(:ok)
          expect(response.json[:status]).to eq "ok"
          expect(response.json[:items].length).to eq 5
          expect(response.json[:items].first[:name]).to eq "repo_2"
          expect(response.json[:total_pages]).to eq 1
          expect(response.json[:current_page]).to eq 1

          expect(response.json[:prev_page]).to be_nil
          expect(response.json[:next_page]).to be_nil
        end

        expect(call).not_to have_enqueued_job
      end
    end

    describe "trigram failure regression" do
      before do
        mock_redis!
        bypass_redlock!
        stub_const("V1::RepositoriesController::REPOSITORIES_PER_PAGE", 50)
        @cache.set("cocov:github_org_repos:status", "present")
        @cache.set("cocov:github_org_repos:items", fixture_file("repositories_controller", "trigram_regression.json"))
        @cache.set("cocov:github_org_repos:etag",
          "W/\"3ea229c6eec1003e95ff9eee8f7374d3b373b9e5157b5efdf1f6ecf56fa0da6a\"")
        @cache.set("cocov:github_org_repos:updated_at", Time.now.utc.iso8601)
      end

      it "performs searches" do
        call = lambda do
          get "/v1/repositories/$org_repos",
            params: { search_term: "web" },
            headers: authenticated

          expect(response).to have_http_status(:ok)
          expect(response.json[:status]).to eq "ok"
          expect(response.json[:items].first[:name]).to eq "web"
          expect(response.json[:total_pages]).to eq 1
          expect(response.json[:current_page]).to eq 1

          expect(response.json[:prev_page]).to be_nil
          expect(response.json[:next_page]).to be_nil
        end

        expect(call).not_to have_enqueued_job
      end
    end
  end
end
