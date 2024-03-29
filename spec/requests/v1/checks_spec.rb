# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::Checks" do
  describe "#index" do
    it "returns 404 when repository does not exist" do
      get "/v1/repositories/dummy/commits/bla/checks", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 when commit does not exist" do
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/bla/checks", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns a valid response in case checks haven't started" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks", headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json[:status]).to eq "waiting"
    end

    it "returns checks" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      checks = [
        create(:check, commit:),
        create(:check, :in_progress, commit:),
        create(:check, :completed, commit:),
        create(:check, :errored, commit:)
      ]
      commit.check_set.in_progress!
      @user = create(:user)
      grant(@user, access_to: repo)

      checks.each { create(:issue, commit:, check_source: _1.plugin_name) }

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks", headers: authenticated
      expect(response).to have_http_status(:ok)

      checks.each do |c|
        expectation = { "id" => c.id, "plugin_name" => c.plugin_name, "status" => c.status.to_s }
        if c.in_progress?
          expectation["started_at"] = c.started_at.iso8601
        elsif c.completed? || c.errored?
          expectation["started_at"] = c.started_at.iso8601
          expectation["finished_at"] = c.finished_at.iso8601
        end

        expect(response.json[:checks]).to include(expectation)
        expect(response.json[:status]).to eq "in_progress"
        expect(response.json[:issues]).to eq(checks.map(&:plugin_name).index_with { 1 })
      end
    end

    it "returns failures with user-visible information" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      allow(commit).to receive(:create_github_status)
        .with(anything, anything)
        .and_return(nil)
      commit.notify_check_fatal_failure!(Cocov::Manifest::InvalidManifestError.new(
        :manifest_unknown_secret,
        "Unknown secret `FOO'"
      ))
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks", headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json[:status]).to eq "failure"
      expect(response.json[:failure_reason]).to eq "manifest_unknown_secret"
      expect(response.json[:failure_details]).to eq "Unknown secret `FOO'"
    end

    it "returns failures without user-visible information" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      allow(commit).to receive(:create_github_status)
        .with(anything, anything)
        .and_return(nil)
      commit.notify_check_fatal_failure!(Cocov::Manifest::InvalidManifestError.new(
        :manifest_missing_version,
        "Manifest missing version"
      ))
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks", headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json[:status]).to eq "failure"
      expect(response.json[:failure_reason]).to eq "manifest_missing_version"
      expect(response.json).not_to have_key(:failure_details)
    end
  end

  describe "#show" do
    it "returns 404 when repository does not exist" do
      get "/v1/repositories/dummy/commits/bla/checks/bla", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 when commit does not exist" do
      repo = create(:repository)
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/bla/checks/bla", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 when check does not exist" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks/bla", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns basic info for non-error checks" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      @user = create(:user)
      grant(@user, access_to: repo)
      check = create(:check, commit:)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks/#{check.id}", headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({
        "id" => check.id,
        "plugin_name" => check.plugin_name,
        "status" => check.status.to_s
      })
    end

    it "returns error information for errored checks" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      check = create(:check, :errored, commit:)
      @user = create(:user)
      grant(@user, access_to: repo)

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks/#{check.id}", headers: authenticated
      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({
        "id" => check.id,
        "plugin_name" => check.plugin_name,
        "status" => check.status.to_s,
        "started_at" => check.started_at.iso8601,
        "finished_at" => check.finished_at.iso8601,
        "error_output" => check.error_output
      })
    end
  end

  describe "#patch" do
    it "validates plugin_name" do
      patch "/v1/repositories/x/commits/x/checks",
        headers: authenticated(as: :service),
        params: { status: "in_progress" }

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:checks, :missing_plugin_name)
    end

    it "validates status presence" do
      patch "/v1/repositories/x/commits/x/checks",
        headers: authenticated(as: :service),
        params: { plugin_name: "foo" }

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:checks, :missing_status)
    end

    it "validates status type" do
      patch "/v1/repositories/x/commits/x/checks",
        headers: authenticated(as: :service),
        params: { status: "bla", plugin_name: "foo" }

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:checks, :invalid_status)
    end

    it "validates error_output when status is errored" do
      patch "/v1/repositories/x/commits/x/checks",
        headers: authenticated(as: :service),
        params: { status: "errored", plugin_name: "foo" }

      expect(response).to have_http_status(:bad_request)
      expect(response).to be_a_json_error(:checks, :missing_error_output)
    end

    it "returns 404 in case repository does not exist" do
      patch "/v1/repositories/x/commits/x/checks",
        headers: authenticated(as: :service),
        params: { status: "in_progress", plugin_name: "foo" }

      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 in case commit does not exist" do
      repo = create(:repository)
      patch "/v1/repositories/#{repo.id}/commits/x/checks",
        headers: authenticated(as: :service),
        params: { status: "in_progress", plugin_name: "foo" }

      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 in case check does not exist" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "in_progress", plugin_name: "foo" }

      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    describe "updates check" do
      let(:check) { create(:check, :with_commit) }
      let(:commit) { check.check_set.commit }
      let(:repo) { check.check_set.commit.repository }

      it "for status in_progress" do
        patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
          headers: authenticated(as: :service),
          params: { status: "in_progress", plugin_name: check.plugin_name }

        expect(response).to have_http_status(:no_content)
        check.reload
        expect(check.started_at).not_to be_nil
      end

      it "for status completed" do
        patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
          headers: authenticated(as: :service),
          params: { status: "completed", plugin_name: check.plugin_name }

        expect(response).to have_http_status(:no_content)
        check.reload
        expect(check.started_at).not_to be_nil
        expect(check.finished_at).not_to be_nil
      end

      it "for status errored" do
        patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
          headers: authenticated(as: :service),
          params: { status: "errored", error_output: "boom", plugin_name: check.plugin_name }

        expect(response).to have_http_status(:no_content)
        check.reload
        expect(check.started_at).not_to be_nil
        expect(check.finished_at).not_to be_nil
        expect(check.error_output).to eq "boom"
      end
    end
  end

  describe "#summary" do
    it "returns summaries" do
      repo = create(:repository)
      commit = create(:commit, repository: repo)
      @user = create(:user)
      grant(@user, access_to: repo)

      Timecop.freeze do
        create(:check, commit:, plugin_name: "cocov/rubocop", started_at: 3.seconds.ago, finished_at: Time.zone.now,
          status: :completed)
        create(:check, commit:, plugin_name: "cocov/brakeman", started_at: 3.seconds.ago, status: :in_progress)
        create(:check, commit:, plugin_name: "cocov/boom", started_at: 3.seconds.ago, finished_at: Time.zone.now,
          status: :errored, error_output: "bam!")
      end

      create_list(:issue, 3, commit:, check_source: "cocov/rubocop")

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks/summary",
        headers: authenticated

      expect(response).to have_http_status :ok
      expect(response.json.first[:name]).to eq "cocov/boom"
      expect(response.json.first[:status]).to eq "errored"
      expect(response.json.first[:duration]).to eq 3

      expect(response.json.second[:name]).to eq "cocov/brakeman"
      expect(response.json.second[:status]).to eq "in_progress"

      expect(response.json.third[:name]).to eq "cocov/rubocop"
      expect(response.json.third[:status]).to eq "completed"
      expect(response.json.third[:duration]).to eq 3
      expect(response.json.third[:issue_count]).to eq 3
    end
  end

  describe "#patch_job" do
    let(:check_a) { create(:check, :with_commit) }
    let(:commit) { check_a.check_set.commit }
    let(:repo) { commit.repository }
    let(:branch) { create(:branch, repository: repo, head: commit) }
    let(:check_b) { create(:check, commit: branch.head) }

    before { stub_configuration! }

    it "marks the job as completed if all checks succeed" do
      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "completed", plugin_name: check_a.plugin_name }
      expect(response).to have_http_status(:no_content)

      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "completed", plugin_name: check_b.plugin_name }
      expect(response).to have_http_status(:no_content)

      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:create_status).with(
        "#{@github_organization_name}/#{repo.name}",
        commit.sha,
        "success",
        description: "No issues detected",
        context: "cocov",
        target_url: "#{Cocov::UI_BASE_URL}/repos/#{repo.name}/commits/#{commit.sha}/checks"
      )

      post "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks/wrap_up",
        headers: authenticated(as: :service)
      expect(response).to have_http_status(:no_content)

      commit.reload
      expect(commit.issues_count).to eq 0
      expect(commit.check_set).to be_completed
    end

    it "marks the job as errored if any check fails" do
      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "completed", plugin_name: check_a.plugin_name }
      expect(response).to have_http_status(:no_content)

      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "errored", error_output: "boom", plugin_name: check_b.plugin_name }
      expect(response).to have_http_status(:no_content)

      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:create_status).with(
        "#{@github_organization_name}/#{repo.name}",
        commit.sha,
        "error",
        description: "An internal error occurred",
        context: "cocov",
        target_url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks"
      )

      post "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks/wrap_up",
        headers: authenticated(as: :service)
      expect(response).to have_http_status(:no_content)

      commit.reload
      expect(commit.issues_count).to eq 0
      expect(commit.check_set).to be_errored
    end

    it "marks the job as completed and emits issue counts to GitHub" do
      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "completed", plugin_name: check_a.plugin_name }
      expect(response).to have_http_status(:no_content)

      allow(ManifestService).to receive(:manifest_for_commit)
        .with(-> { _1.id == commit.id })
        .and_return(nil)

      put "/v1/repositories/#{repo.id}/issues",
        headers: authenticated(as: :service),
        as: :json,
        params: {
          sha: commit.sha,
          source: check_b.plugin_name,
          issues: [
            { uid: "rubocop-a", file: "app.rb", line_start: 1, line_end: 2, message: "something is wrong",
              kind: "bug" }
          ]
        }
      expect(response).to have_http_status(:no_content)

      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "completed", plugin_name: check_b.plugin_name }
      expect(response).to have_http_status(:no_content)

      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:create_status).with(
        "#{@github_organization_name}/#{repo.name}",
        commit.sha,
        "failure",
        description: "1 issue detected",
        context: "cocov",
        target_url: "#{@ui_base_url}/repos/#{repo.name}/commits/#{commit.sha}/issues"
      )

      post "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks/wrap_up",
        headers: authenticated(as: :service)
      expect(response).to have_http_status(:no_content)

      commit.reload
      expect(commit.issues_count).to eq 1
      expect(commit.check_set).to be_completed
    end
  end

  describe "#re_run" do
    let(:check) { create(:check, :in_progress, :with_commit) }
    let(:commit) { check.check_set.commit }
    let(:repo) { commit.repository }

    before do
      stub_configuration!
      bypass_redlock!
      mock_redis!
      stub_crypto_key!
    end

    it "refuses to re-run an in-progress job" do
      check.check_set.in_progress!

      post "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks/re_run",
        headers: authenticated(as: :service)
      expect(response).to be_a_json_error(:checks, :cannot_re_run_while_running)
    end

    it "re-runs a finished job" do
      check.check_set.canceled!

      expect(GitService).to receive(:clone_commit).with(anything)
      expect(GitService).to receive(:file_for_commit)
        .with(commit, path: ".cocov.yaml")
        .and_return(["yaml", fixture_file("manifests/v0.1alpha/complete.yaml")])

      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:create_status).with(
        "#{@github_organization_name}/#{repo.name}",
        commit.sha,
        "pending",
        context: "cocov",
        description: "Checks are running...",
        target_url: "#{Cocov::UI_BASE_URL}/repos/#{repo.name}/commits/#{commit.sha}/checks"
      )

      expect(@redis.llen("cocov:checks")).to be_zero
      allow(SecureRandom).to receive(:uuid).and_return("this-is-an-uuid")
      allow(SecureRandom).to receive(:hex).with(anything).and_return("23035196471c5ab5b3b5b03ee9bf494215defa61457311d6")

      create(:secret, :with_owner, name: "FOO")

      post "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks/re_run",
        headers: authenticated(as: :service)

      expect(@redis.llen("cocov:checks")).to eq 1
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "#cancel" do
    let(:check) { create(:check, :in_progress, :with_commit) }
    let(:commit) { check.check_set.commit }
    let(:repo) { commit.repository }

    before do
      stub_configuration!
      bypass_redlock!
      mock_redis!
    end

    it "requests a job cancelation" do
      check.check_set.job_id = "a-job-id"
      check.check_set.save!

      @redis.define_singleton_method(:publish) do |*_args, **_kwargs, &_block|
        raise NotImplementedError
      end

      expect(@redis).to receive(:publish).with("cocov:checks_control", {
        "check_set_id" => check.check_set.id,
        "job_id" => "a-job-id",
        "operation" => "cancel"
      }.to_json).once.and_return(nil)

      delete "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks",
        headers: authenticated
      expect(response).to have_http_status(:no_content)

      delete "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks",
        headers: authenticated
      expect(response).to have_http_status(:no_content)

      patch "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "canceled", plugin_name: check.plugin_name }

      expect(response).to have_http_status(:no_content)

      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:create_status).with(
        "#{@github_organization_name}/#{repo.name}",
        commit.sha,
        "failure",
        description: "Checks were canceled",
        context: "cocov",
        target_url: "#{Cocov::UI_BASE_URL}/repos/#{commit.repository.name}/commits/#{commit.sha}/checks"
      )

      post "/v1/repositories/#{repo.id}/commits/#{commit.sha}/checks/wrap_up",
        headers: authenticated(as: :service)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "#notify_in_progress" do
    let(:check) { create(:check, :with_commit) }
    let(:commit) { check.check_set.commit }
    let(:repo) { commit.repository }
    let(:set) { check.check_set }

    it "marks a set as in_progress" do
      post "/v1/repositories/#{repo.id}/commits/#{commit.sha}/check_set/notify_in_progress",
        headers: authenticated(as: :service)
      expect(response).to have_http_status(:no_content)

      expect(set.reload).to be_in_progress
    end

    %i[errored completed canceled].each do |status|
      it "does not mark an #{status} set as in_progress" do
        set.send("#{status}!")

        post "/v1/repositories/#{repo.id}/commits/#{commit.sha}/check_set/notify_in_progress",
          headers: authenticated(as: :service)
        expect(response).to have_http_status(:no_content)

        expect(set.reload).to send("be_#{status}")
      end
    end
  end
end
