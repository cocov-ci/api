# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Coverage" do
  describe "#put" do
    let(:payload) { fixture_file("coverage_data.json") }

    it "requires repository authentication" do
      post "/v1/reports",
        headers: authenticated

      expect(response).to have_http_status(:unauthorized)
      expect(response).to be_a_json_error(:auth, :invalid_token)
    end

    it "rejects unknown tokens" do
      post "/v1/reports",
        headers: { "HTTP_AUTHORIZATION" => "token foobar" }

      expect(response).to have_http_status(:forbidden)
      expect(response).to be_a_json_error(:auth, :forbidden)
    end

    it "requires data" do
      repo = create(:repository)

      post "/v1/reports",
        headers: { "HTTP_AUTHORIZATION" => "token #{repo.token}" }

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:report, :missing_data)
    end

    it "requires sha" do
      repo = create(:repository)

      post "/v1/reports",
        params: { data: "bla" },
        headers: { "HTTP_AUTHORIZATION" => "token #{repo.token}" }

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:report, :missing_commit_sha)
    end

    it "stores data in case commit does not exist" do
      mock_redis!

      repo = create(:repository)

      expect do
        post "/v1/reports",
          params: JSON.parse(payload),
          headers: { "HTTP_AUTHORIZATION" => "token #{repo.token}" }
      end.not_to have_enqueued_job

      expect(response).to have_http_status(:no_content)
      expect(@redis.exists?("commit:coverage:#{repo.id}:f3075304ba198d9aba419778c7babae2294e3490")).to be true
    end

    it "dispatches coverage jobs in case the commit exists" do
      mock_redis!

      repo = create(:repository)
      create(:commit, repository: repo, sha: "f3075304ba198d9aba419778c7babae2294e3490")

      expect do
        post "/v1/reports",
          params: JSON.parse(payload),
          headers: { "HTTP_AUTHORIZATION" => "token #{repo.token}" }
      end.to have_enqueued_job

      expect(response).to have_http_status(:no_content)
      expect(@redis.exists?("commit:coverage:#{repo.id}:f3075304ba198d9aba419778c7babae2294e3490")).to be false
    end
  end

  describe "#summary" do
    it "returns summary" do
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)
      commit = create(:commit, repository: repo)
      ci = create(:coverage_info, commit:, status: :ready)
      perc = 0
      10.times do
        create(:coverage_file, coverage: ci, percent_covered: perc)
        perc += 10
      end

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/coverage/summary",
        headers: authenticated

      expect(response).to have_http_status(:ok)
      expect(response.json[:status]).to eq "ready"
      expect(response.json[:percent_covered]).to eq 50
      expect(response.json[:lines_total]).to eq 100
      expect(response.json[:least_covered].first[:percent_covered]).to eq 0
      expect(response.json[:least_covered].last[:percent_covered]).to eq 90
    end
  end

  describe "#index" do
    it "returns a list of files and their percentages" do
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)
      commit = create(:commit, repository: repo)
      ci = create(:coverage_info, commit:, status: :ready)
      perc = 0
      10.times do
        create(:coverage_file, coverage: ci, percent_covered: perc)
        perc += 10
      end
      commit.coverage_processed!

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/coverage",
        headers: authenticated

      expect(response).to have_http_status :ok
      expect(response.json[:status]).to eq "processed"
      expect(response.json[:files].first[:percent_covered]).to eq 0
      expect(response.json[:files].last[:percent_covered]).to eq 90
    end
  end

  describe "#show" do
    it "returns coverage information" do
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)
      commit = create(:commit, repository: repo)
      ci = create(:coverage_info, commit:, status: :ready)
      file = create(:coverage_file, coverage: ci, percent_covered: 50)
      commit.coverage_processed!
      commit.clone_completed!

      storage = double(:storage)
      expect(storage).to receive(:file_for_commit).with(anything, path: "foo/bar.rb").and_return("def foo\nend")
      allow(GitService).to receive(:storage).and_return storage

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/coverage/file/#{file.id}",
        headers: authenticated

      expect(response).to have_http_status :ok
      expect(response.json).to eq({
        "file" => { "base_path" => "foo/", "name" => "bar.rb", "source" => "def foo\nend" },
        "coverage" => {
          "lines_covered" => 1,
          "lines_total" => 2,
          "percent_covered" => 50,
          "blocks" => [
            { "kind" => "missed", "start" => 1, "end" => 1 },
            { "kind" => "neutral", "start" => 2, "end" => 2 }
          ]
        }
      })
    end
  end
end
