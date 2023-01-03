# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Issues" do
  it "returns 404 when repository does not exist" do
    get "/v1/repositories/bla/badges/coverage",
      headers: authenticated(as: :service)

    expect(response).to have_http_status(:not_found)
    expect(response).to be_a_json_error(:not_found)
  end

  it "returns unknown in case default branch does not exist" do
    repo = create(:repository)
    get "/v1/repositories/#{repo.name}/badges/coverage",
      headers: authenticated(as: :service)

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq "unknown"
  end

  describe "coverage" do
    it "returns unknown in case coverage is not set" do
      repo = create(:repository)
      create(:branch, name: "master", repository: repo, coverage: nil)

      get "/v1/repositories/#{repo.name}/badges/coverage",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq "unknown"
    end

    it "returns the coverage percentage when it is set" do
      repo = create(:repository)
      create(:branch, name: "master", repository: repo, coverage: 50)

      get "/v1/repositories/#{repo.name}/badges/coverage",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq "50"
    end

    it "returns the coverage percentage when it is zero" do
      repo = create(:repository)
      create(:branch, name: "master", repository: repo, coverage: 0)

      get "/v1/repositories/#{repo.name}/badges/coverage",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq "0"
    end
  end

  describe "issues" do
    it "returns unknown in case issues is not set" do
      repo = create(:repository)
      create(:branch, name: "master", repository: repo, issues: nil)

      get "/v1/repositories/#{repo.name}/badges/issues",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq "unknown"
    end

    it "returns the issues percentage when it is set" do
      repo = create(:repository)
      create(:branch, name: "master", repository: repo, issues: 50)

      get "/v1/repositories/#{repo.name}/badges/issues",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq "50"
    end

    it "returns 0 when issues is empty" do
      repo = create(:repository)
      create(:branch, name: "master", repository: repo, issues: 0)

      get "/v1/repositories/#{repo.name}/badges/issues",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq "0"
    end
  end
end
