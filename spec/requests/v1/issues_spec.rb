# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Issues" do
  describe "#index" do
    it "returns 404 when repository does not exist" do
      get "/v1/repositories/dummy/commits/foo/issues", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 when commit does not exist" do
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/foo/issues", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns an empty array when commit has no registered issues" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues", headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json[:issues]).to be_empty
    end

    it "gets issues of a commit" do
      stub_configuration!

      commit = create(:commit, :with_repository)
      commit.clone_completed!
      repo = commit.repository
      issue = create(:issue, commit:, line_start: 4, line_end: 4)
      @user = create(:user)
      grant(@user, access_to: repo)

      the_file = Base64.decode64("Y2xhc3MgSGVsbG8KICBhdHRyX2FjY2Vzc29yIDpi" \
                                 "YXIKICAKICBkZWYgZm9vCiAgICBiYXIKICBlbmQKZW5k")

      allow(GitService.storage).to receive(:file_for_commit).and_return(the_file)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues", headers: authenticated
      expect(response).to have_http_status(:ok)

      json = response.json

      response_repo = json[:repository]
      expect(response_repo[:id]).to eq repo.id
      expect(response_repo[:name]).to eq repo.name
      expect(response_repo[:description]).to eq repo.description
      expect(response_repo[:token]).to eq repo.token
      expect(response_repo[:default_branch]).to eq repo.default_branch

      response_commit = json[:commit]
      expect(response_commit[:id]).to eq commit.id
      expect(response_commit[:author_email]).to eq commit.author_email
      expect(response_commit[:author_name]).to eq commit.author_name
      expect(response_commit[:checks_status]).to eq commit.checks_status
      expect(response_commit[:coverage_status]).to eq commit.coverage_status
      expect(response_commit[:sha]).to eq commit.sha
      expect(response_commit[:coverage_percent]).to eq commit.coverage_percent
      expect(response_commit[:issues_count]).to eq 1
      expect(response_commit[:condensed_status]).to eq commit.condensed_status.to_s
      expect(response_commit[:minimum_coverage]).to eq commit.minimum_coverage
      expect(response_commit[:message]).to eq commit.message
      expect(response_commit[:org_name]).to eq @github_organization_name

      expect(json[:issues].count).to eq 1

      prob = json.dig(:issues, 0)
      expect(prob[:id]).to eq issue.id
      expect(prob[:kind]).to eq issue.kind
      expect(prob[:file]).to eq issue.file
      expect(prob[:uid]).to eq issue.uid
      expect(prob[:line_start]).to eq issue.line_start
      expect(prob[:line_end]).to eq issue.line_end
      expect(prob[:message]).to eq issue.message
      expect(prob[:check_source]).to eq issue.check_source
      expect(prob[:affected_file][:status]).to eq "ok"

      expect(prob[:affected_file][:content]).to eq [
        { "type" => "line", "line" => 2,
          "source" => "<pre>  <span class=\"nb\">attr_accessor</span> <span class=\"ss\">:bar</span>\n</pre>" },
        { "type" => "line", "line" => 3, "source" => "<pre>  \n</pre>" },
        { "type" => "line", "line" => 4,
          "source" => "<pre>  <span class=\"k\">def</span> <span class=\"nf\">foo</span>\n</pre>" },
        { "type" => "warn", "text" => "something is wrong", "padding" => "  " },
        { "type" => "line", "line" => 5, "source" => "<pre>    <span class=\"n\">bar</span>\n</pre>" },
        { "type" => "line", "line" => 6, "source" => "<pre>  <span class=\"k\">end</span>\n</pre>" }
      ]
    end

    it "filters issues" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      @user = create(:user)
      grant(@user, access_to: repo)
      create(:issue, check_source: "test_a", commit:)
      create(:issue, check_source: "test_b", commit:)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues",
        params: { source: "test_a" },
        headers: authenticated

      expect(response).to have_http_status(:ok)
      expect(response.json[:issues].length).to eq 1
      expect(response.json[:issues].first[:check_source]).to eq "test_a"
    end
  end

  describe "#put" do
    before { stub_configuration! }

    it "requires a JSON body" do
      put "/v1/repositories/foo/issues",
        params: { just_a_param: "value" },
        headers: authenticated(format: :url_encoded_form, as: :service)

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:issues, :json_required)
    end

    ok_request = {
      sha: "",
      source: :a,
      issues: [
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" }
      ]
    }.freeze

    cases = {
      "sha" => ok_request.dup.merge({
        sha: 0
      }),
      "source" => ok_request.dup.merge({
        source: 0
      }),
      "issues" => ok_request.dup.merge({ issues: {} }),
      "issues.0.uid" => ok_request.dup.merge({
        issues: [
          { uid: 0, file: "", line_start: 0, line_end: 0, message: "", kind: "" }
        ]
      }),
      "issues.0.file" => ok_request.dup.merge({
        issues: [
          { uid: "", file: 0, line_start: 0, line_end: 0, message: "", kind: "" }
        ]
      }),
      "issues.0.line_start" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: "", line_end: 0, message: "", kind: "" }
        ]
      }),
      "issues.0.line_end" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: 0, line_end: "", message: "", kind: "" }
        ]
      }),
      "issues.0.message" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: 0, line_end: 0, message: 0, kind: "" }
        ]
      }),
      "issues.0.kind" => ok_request.dup.merge({
        issues: [
          { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: 0 }
        ]
      })
    }.freeze

    cases.each do |name, req|
      it "rejects when #{name} is invalid" do
        put "/v1/repositories/foo/issues",
          params: req,
          headers: authenticated(as: :service),
          as: :json
        expect(response).to have_http_status(:bad_request)
        expect(response).to be_a_json_error(:issues, :validation_error)
        expect(response.json[:message]).to include(name)
      end
    end

    it "stores new issues" do
      repo = create(:repository)
      commit = create(:commit, repository: repo, sha: "65f4e0c879eb83460260637880fb82f188065d11")
      commit.reset_check_set!

      put "/v1/repositories/#{repo.id}/issues",
        headers: authenticated(as: :service),
        as: :json,
        params: {
          sha: "65f4e0c879eb83460260637880fb82f188065d11",
          source: "cocov/rubocop:v0.1",
          issues: [
            { uid: "rubocop-a", file: "app.rb", line_start: 1, line_end: 2, message: "something is wrong",
              kind: "bug" }
          ]
        }
      expect(response).to have_http_status :no_content
      expect(repo.commits.count).to eq 1
      expect(repo.commits.first.issues.count).to eq 1
      probl = repo.commits.first.issues.first

      expect(probl).to be_bug
      expect(probl.uid).to eq "rubocop-a"
      expect(probl.file).to eq "app.rb"
      expect(probl.line_start).to eq 1
      expect(probl.line_end).to eq 2
      expect(probl.message).to eq "something is wrong"
      expect(probl.check_source).to eq "cocov/rubocop"
    end

    it "recycles issues" do
      repo = create(:repository)
      commit = create(:commit, repository: repo, sha: "65f4e0c879eb83460260637880fb82f188065d11")
      commit.reset_check_set!

      request = {
        headers: authenticated(as: :service),
        as: :json,
        params: {
          sha: "65f4e0c879eb83460260637880fb82f188065d11",
          source: :a,
          issues: [
            { uid: "rubocop-a", file: "app.rb", line_start: 1, line_end: 2, message: "something is wrong",
              kind: "bug" }
          ]
        }
      }

      put "/v1/repositories/#{repo.id}/issues", **request

      expect(response).to have_http_status :no_content
      expect(repo.commits.count).to eq 1
      expect(repo.commits.first.issues.count).to eq 1

      put "/v1/repositories/#{repo.id}/issues", **request

      expect(response).to have_http_status :no_content
      expect(repo.commits.count).to eq 1
      expect(repo.commits.first.issues.count).to eq 1
    end

    it "handles an empty issue list" do
      repo = create(:repository)
      commit = create(:commit, repository: repo, sha: "65f4e0c879eb83460260637880fb82f188065d11")
      commit.reset_check_set!

      put "/v1/repositories/#{repo.id}/issues",
        headers: authenticated(as: :service),
        as: :json,
        params: {
          sha: "65f4e0c879eb83460260637880fb82f188065d11",
          source: :a,
          issues: []
        }

      expect(response).to have_http_status :no_content
      expect(repo.commits.count).to eq 1
      expect(repo.commits.first.issues.count).to eq 0
    end

    it "accepts nil arrays of issues" do
      payload = {
        "source" => "cocov/brakeman",
        "issues" => [
          {
            "kind" => "security",
            "file" => "app/services/git_service/base_storage.rb",
            "line_start" => 23,
            "line_end" => 23,
            "message" => "Weak hashing algorithm used: SHA1",
            "uid" => "12a75d7df840a95bd9da0d107848829a0ac67d2ebf0d2f65a4ed9d0ca7d813e6"
          },
          {
            "kind" => "security",
            "file" => "app/controllers/v1/github_events_controller.rb",
            "line_start" => 41,
            "line_end" => 41,
            "message" => "Possible SQL injection",
            "uid" => "205e1c2f2546dc345358bb4d2575846621e643e66542fa4fbe5013fb840d72ff"
          },
          {
            "kind" => "security",
            "file" => "app/controllers/v1/coverage_controller.rb",
            "line_start" => 38,
            "line_end" => 38,
            "message" => "Possible SQL injection",
            "uid" => "254a5b19feba0aba48e51ce7aa10e699822d9f33d3e0997b29d5cac41ef47054"
          },
          {
            "kind" => "security",
            "file" => "app/models/application_record.rb",
            "line_start" => 12,
            "line_end" => 12,
            "message" => "Possible SQL injection",
            "uid" => "361af13dc4740b03b4e07802cc6dde22e383add96d02d6b34dcada0051fcaa1d"
          },
          {
            "kind" => "security",
            "file" => "app/controllers/v1/github_events_controller.rb",
            "line_start" => 87,
            "line_end" => 87,
            "message" => "Possible SQL injection",
            "uid" => "3a9713c28f900693d929054037b17cf1464e23c5472b853eb43537c4734cf77b"
          },
          {
            "kind" => "security",
            "file" => "app/services/git_service.rb",
            "line_start" => 35,
            "line_end" => 35,
            "message" => "Weak hashing algorithm used: SHA1",
            "uid" => "3e931ec5cd0ebffd5739fe9e9ae6706250784daab812a27c585b15817b5bc5a3"
          },
          {
            "kind" => "security",
            "file" => "app/controllers/v1/coverage_controller.rb",
            "line_start" => 42,
            "line_end" => 42,
            "message" => "Specify exact keys allowed for mass assignment",
            "uid" => "483af335c6d4afbdc9bc7b2493e8fd7f97a51988d6bbe1616f5509d9bc4af76a"
          },
          {
            "kind" => "security",
            "file" => "app/controllers/v1/github_events_controller.rb",
            "line_start" => 21,
            "line_end" => 21,
            "message" => "User controlled method execution",
            "uid" => "5d138b57cdd2465149a4e7deb968dfa5b9d03624ea7c50b3e22d04788e7c7899"
          },
          {
            "kind" => "security",
            "file" => "config/environments/production.rb",
            "line_start" => 1,
            "line_end" => 1,
            "message" => "The application does not force use of HTTPS: `config.force_ssl` is not enabled",
            "uid" => "6a26086cd2400fbbfb831b2f8d7291e320bcc2b36984d2abc359e41b3b63212b"
          },
          {
            "kind" => "security",
            "file" => "app/lib/cocov/redis.rb",
            "line_start" => 77,
            "line_end" => 77,
            "message" => "Possible SQL injection",
            "uid" => "dc667765f93bd6c3d3e0927d86ebd960196cf4c099e64ed466db4dbf17053005"
          }
        ],
        "sha" => "a36aaecf08cdf39970efd816ebc05d515f8fc391",
        "repo_name" => "api"
      }

      repo = create(:repository)
      commit = create(:commit, sha: "a36aaecf08cdf39970efd816ebc05d515f8fc391", repository: repo)
      commit.reset_check_set!

      put "/v1/repositories/#{repo.id}/issues",
        headers: authenticated(as: :service),
        as: :json,
        params: payload

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "#sources" do
    it "returns sources for current issues" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      @user = create(:user)
      grant(@user, access_to: repo)
      sources = %w[foo bar baz]

      sources.each.with_index do |name, idx|
        n = "cocov-ci/#{name}"
        create(:check, :succeeded, commit:, plugin_name: n)
        (idx + 1).times do
          create(:issue, commit:, check_source: n)
        end
      end

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/sources",
        headers: authenticated

      expect(response).to have_http_status :ok
      sources.each.with_index do |n, idx|
        expect(response.json["cocov-ci/#{n}"]).to eq idx + 1
      end
    end
  end

  describe "#categories" do
    it "returns categories for current issues" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      @user = create(:user)
      grant(@user, access_to: repo)
      categories = %w[security performance style]

      categories.each.with_index do |name, idx|
        check = create(:check, :succeeded, commit:)
        (idx + 1).times do
          create(:issue, commit:, check_source: check.plugin_name, kind: name)
        end
      end

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/categories",
        headers: authenticated

      expect(response).to have_http_status :ok
      categories.each.with_index do |n, idx|
        expect(response.json[n.to_s]).to eq idx + 1
      end
    end
  end

  describe "#ignore" do
    let(:commit) { create(:commit, :with_repository) }
    let(:repo) { commit.repository }
    let(:issue) { create(:issue, commit: commit) }

    before do
      @user = create(:user)
      grant(@user, access_to: repo)
    end

    it "have no effect in case an issue is already ignored" do
      issue.ignore_permanently! user: @user, reason: "bla"

      post "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/#{issue.id}/ignore",
        params: { mode: "ephemeral", reason: "Test" },
        headers: authenticated

      expect(response).to have_http_status(:ok)
      expect(response.json.dig(:ignored, :ignore_source)).to eq "rule"
    end

    it "requires a valid operation mode" do
      post "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/#{issue.id}/ignore",
        params: { mode: "test", reason: "Test" },
        headers: authenticated

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:issues, :invalid_ignore_mode)
    end

    it "ignores a single issue" do
      post "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/#{issue.id}/ignore",
        params: { mode: "ephemeral", reason: "Test" },
        headers: authenticated

      expect(response).to have_http_status :ok
      ignore = response.json[:ignored]
      expect(ignore[:ignore_source]).to eq "user"
      expect(ignore.dig(:ignored_by, :name)).to eq @user.login
      expect(ignore.dig(:ignored_by, :avatar)).to eq @user.avatar_url
      expect(ignore[:reason]).to eq "Test"
      expect(IssueIgnoreRule.count).to eq 0
    end

    it "permanently ignores an issue" do
      post "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/#{issue.id}/ignore",
        params: { mode: "permanent", reason: "Test" },
        headers: authenticated

      expect(response).to have_http_status :ok

      ignore = response.json[:ignored]
      expect(ignore[:ignore_source]).to eq "rule"
      expect(ignore.dig(:ignored_by, :name)).to eq @user.login
      expect(ignore.dig(:ignored_by, :avatar)).to eq @user.avatar_url
      expect(ignore[:reason]).to eq "Test"
      expect(IssueIgnoreRule.count).to eq 1
    end
  end

  describe "#cancel_ignore" do
    let(:commit) { create(:commit, :with_repository) }
    let(:repo) { commit.repository }
    let(:issue) { create(:issue, commit: commit) }

    before do
      @user = create(:user)
      grant(@user, access_to: repo)
    end

    it "removes the ignore flag set by a user" do
      issue.ignore! user: @user, reason: "test"

      delete "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/#{issue.id}/ignore",
        headers: authenticated

      expect(response).to have_http_status :ok
      expect(response.json[:ignore]).to be_nil
    end

    it "removes the ignore flag set by a rule" do
      issue.ignore_permanently! user: @user, reason: "test"

      delete "/v1/repositories/#{repo.name}/commits/#{commit.sha}/issues/#{issue.id}/ignore",
        headers: authenticated

      expect(response).to have_http_status :ok
      expect(response.json[:ignore]).to be_nil
    end
  end
end
