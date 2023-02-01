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

  describe "#coverage" do
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

  describe "#issues" do
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

    it "correctly handles preloaded branches (issue #1)" do
      repo = create(:repository)
      create(:branch, name: "foo", repository: repo, issues: nil)
      create(:branch, name: "master", repository: repo, issues: 10)

      get "/v1/repositories/#{repo.name}/badges/issues",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq "10"
    end
  end

  describe "#index" do
    let(:repo) { create(:repository) }

    it "returns 204 when not configured" do
      get "/v1/repositories/#{repo.name}/badges",
        headers: authenticated

      expect(response).to have_http_status :no_content
    end

    it "returns data when configured" do
      stub_configuration!

      get "/v1/repositories/#{repo.name}/badges",
        headers: authenticated

      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({
        "coverage_badge_url" => "#{@badges_base_url}/#{repo.name}/coverage",
        "coverage_badge_href" => "#{@ui_base_url}/repos/#{repo.name}",
        "issues_badge_url" => "#{@badges_base_url}/#{repo.name}/issues",
        "issues_badge_href" => "#{@ui_base_url}/repos/#{repo.name}",
        "templates" => {
          "html" => {
            "coverage" => "<a href=\"#{@ui_base_url}/repos/#{repo.name}\"><img src=\"#{@badges_base_url}/#{repo.name}/coverage\" /></a>\n",
            "issues" => "<a href=\"#{@ui_base_url}/repos/#{repo.name}\"><img src=\"#{@badges_base_url}/#{repo.name}/issues\" /></a>\n"
          },
          "markdown" => {
            "coverage" => "[![Coverage](#{@badges_base_url}/#{repo.name}/coverage)](#{@ui_base_url}/repos/#{repo.name})\n",
            "issues" => "[![Issues](#{@badges_base_url}/#{repo.name}/issues)](#{@ui_base_url}/repos/#{repo.name})\n"
          },
          "textile" => {
            "coverage" => "\"!#{@badges_base_url}/#{repo.name}/coverage!\":#{@ui_base_url}/repos/#{repo.name}\n",
            "issues" => "\"!#{@badges_base_url}/#{repo.name}/issues!\":#{@ui_base_url}/repos/#{repo.name}\n"
          },
          "rdoc" => {
            "coverage" => "{<img src=\"#{@badges_base_url}/#{repo.name}/coverage\" />}[#{@ui_base_url}/repos/#{repo.name}]\n",
            "issues" => "{<img src=\"#{@badges_base_url}/#{repo.name}/issues\" />}[#{@ui_base_url}/repos/#{repo.name}]\n"
          },
          "restructured" => {
            "coverage" => ".. image:: #{@badges_base_url}/#{repo.name}/coverage\n " \
                          ":target: #{@ui_base_url}/repos/#{repo.name}\n " \
                          ":alt: Coverage\n",
            "issues" => ".. image:: #{@badges_base_url}/#{repo.name}/issues\n " \
                        ":target: #{@ui_base_url}/repos/#{repo.name}\n " \
                        ":alt: Issues\n"
          }
        }
      })
    end
  end
end
