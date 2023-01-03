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
      get "/v1/repositories/#{repo.name}/commits/bla/checks", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns checks" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      checks = [
        create(:check, commit:),
        create(:check, :running, commit:),
        create(:check, :succeeded, commit:),
        create(:check, :errored, commit:)
      ]

      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks", headers: authenticated
      expect(response).to have_http_status(:ok)

      checks.each do |c|
        expectation = { "id" => c.id, "plugin_name" => c.plugin_name, "status" => c.status.to_s }
        if c.running?
          expectation["started_at"] = c.started_at.iso8601
        elsif c.succeeded? || c.errored?
          expectation["started_at"] = c.started_at.iso8601
          expectation["finished_at"] = c.finished_at.iso8601
        end

        expect(response.json[:checks]).to include(expectation)
      end
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
      get "/v1/repositories/#{repo.name}/commits/bla/checks/bla", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 when check does not exist" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      get "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks/bla", headers: authenticated
      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns basic info for non-error checks" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
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
        params: { status: "running" }

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
        params: { status: "running", plugin_name: "foo" }

      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 in case commit does not exist" do
      repo = create(:repository)
      patch "/v1/repositories/#{repo.name}/commits/x/checks",
        headers: authenticated(as: :service),
        params: { status: "running", plugin_name: "foo" }

      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    it "returns 404 in case check does not exist" do
      commit = create(:commit, :with_repository)
      repo = commit.repository
      patch "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks",
        headers: authenticated(as: :service),
        params: { status: "running", plugin_name: "foo" }

      expect(response).to have_http_status(:not_found)
      expect(response).to be_a_json_error(:not_found)
    end

    describe "updates check" do
      let(:check) { create(:check, :with_commit) }
      let(:commit) { check.commit }
      let(:repo) { check.commit.repository }

      it "for status running" do
        patch "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks",
          headers: authenticated(as: :service),
          params: { status: "running", plugin_name: check.plugin_name }

        expect(response).to have_http_status(:no_content)
        check.reload
        expect(check.started_at).not_to be_nil
      end

      it "for status succeeded" do
        patch "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks",
          headers: authenticated(as: :service),
          params: { status: "succeeded", plugin_name: check.plugin_name }

        expect(response).to have_http_status(:no_content)
        check.reload
        expect(check.started_at).not_to be_nil
        expect(check.finished_at).not_to be_nil
      end

      it "for status errored" do
        patch "/v1/repositories/#{repo.name}/commits/#{commit.sha}/checks",
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
      Timecop.freeze do
        create(:check, commit:, plugin_name: "cocov/rubocop", started_at: 3.seconds.ago, finished_at: Time.zone.now,
          status: :succeeded)
        create(:check, commit:, plugin_name: "cocov/brakeman", started_at: 3.seconds.ago, status: :running)
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
      expect(response.json.second[:status]).to eq "running"

      expect(response.json.third[:name]).to eq "cocov/rubocop"
      expect(response.json.third[:status]).to eq "succeeded"
      expect(response.json.third[:duration]).to eq 3
      expect(response.json.third[:issue_count]).to eq 3
    end
  end
end
