# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::GithubEvents" do
  let(:github_repo_id) { 569_446_274 }

  describe "#process_push" do
    let(:payload) { fixture_file("github/push.json") }

    it "handles incoming push events" do
      mock_redis!

      create(:repository, name: "api", github_id: github_repo_id)
      post "/v1/github/events",
        params: payload,
        headers: github_delivery_header("push")

      expect(response).to have_http_status(:ok)
    end

    it "processes deferred coverages when commit is created on push" do
      mock_redis!

      sha = "6858adf07e5cd43f9c5d87573369fa354d20a076"
      repo = create(:repository, name: "api", github_id: github_repo_id)
      @redis.set("commit:coverage:#{repo.id}:#{repo.id}:#{sha}", { bla: true }.to_json)

      data = JSON.parse(payload)
      data["head_commit"]["id"] = sha

      expect do
        post "/v1/github/events",
          params: data.to_json,
          headers: github_delivery_header("push")

        expect(response).to have_http_status(:ok)
      end.to have_enqueued_job
    end
  end

  describe "#process_repository_edited" do
    it "updates a repository description" do
      repo = create(:repository, description: "foo", github_id: github_repo_id)

      post "/v1/github/events",
        params: fixture_file("github/repository_edit_description.json"),
        headers: github_delivery_header("repository")

      expect(response).to have_http_status(:ok)

      expect(repo.reload.description).to eq "Cocov's API"
    end

    it "updates a repository default branch" do
      repo = create(:repository, default_branch: "foo", github_id: github_repo_id)

      post "/v1/github/events",
        params: fixture_file("github/repository_edit_default_branch.json"),
        headers: github_delivery_header("repository")

      expect(response).to have_http_status(:ok)

      expect(repo.reload.default_branch).to eq "master"
    end
  end

  describe "#process_repository_renamed" do
    it "updates a repository name" do
      repo = create(:repository, name: "foo", github_id: github_repo_id)

      post "/v1/github/events",
        params: fixture_file("github/repository_renamed.json"),
        headers: github_delivery_header("repository")

      expect(response).to have_http_status(:ok)

      expect(repo.reload.name).to eq "renamed"
    end
  end

  describe "#process_delete" do
    it "deletes branches" do
      repo = create(:repository, name: "foo", github_id: github_repo_id)
      create(:branch, name: "test", repository: repo)

      expect(repo.branches.count).to eq 1

      post "/v1/github/events",
        params: fixture_file("github/delete.json"),
        headers: github_delivery_header("delete")

      expect(response).to have_http_status(:ok)

      expect(repo.branches.count).to eq 0
    end
  end

  describe "#process_repository_deleted" do
    it "deletes a repository" do
      create(:repository, name: "test", github_id: github_repo_id)
      expect do
        post "/v1/github/events",
          params: fixture_file("github/repository_deleted.json"),
          headers: github_delivery_header("repository")

        expect(response).to have_http_status(:ok)
      end.to have_enqueued_job
    end
  end

  describe "#organization_member_added" do
    it "schedules users for update" do
      create(:user, github_id: 39_652_351)
      expect do
        post "/v1/github/events",
          params: fixture_file("github/organization_member_added.json"),
          headers: github_delivery_header("organization")

        expect(response).to have_http_status(:ok)
      end.to have_enqueued_job
    end
  end
end
