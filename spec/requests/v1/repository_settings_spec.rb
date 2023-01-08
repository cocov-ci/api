# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::RepositorySettings" do
  let(:repo) { create(:repository) }

  describe "#regen_token" do
    it "regenerates a repository token" do
      current_token = repo.token
      allow(SecureRandom).to receive(:hex).with(anything).and_call_original
      allow(SecureRandom).to receive(:hex).with(21).and_return("yay")
      post "/v1/repositories/#{repo.name}/settings/regen-token",
        headers: authenticated

      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({ "new_token" => "crt_yay" })
      expect(repo.reload.token).not_to eq current_token
    end
  end

  describe "#sync_github" do
    it "updates the repository name" do
      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      fake_repo = double(:fake_repo)
      allow(gh_app).to receive(:repo).with(repo.github_id).and_return(fake_repo)
      allow(fake_repo).to receive(:name).and_return("foobar")
      allow(fake_repo).to receive(:description).and_return(repo.description)

      post "/v1/repositories/#{repo.name}/settings/sync-github",
        headers: authenticated

      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({ "new_name" => "foobar" })
      expect(repo.reload.name).to eq "foobar"
    end

    it "updates the repository description" do
      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      fake_repo = double(:fake_repo)
      allow(gh_app).to receive(:repo).with(repo.github_id).and_return(fake_repo)
      allow(fake_repo).to receive(:name).and_return(repo.name)
      allow(fake_repo).to receive(:description).and_return("foobar")

      post "/v1/repositories/#{repo.name}/settings/sync-github",
        headers: authenticated

      expect(response).to have_http_status(:no_content)
      expect(repo.reload.description).to eq "foobar"
    end
  end

  describe "#delete" do
    it "deletes a repository" do
      expect do
        post "/v1/repositories/#{repo.name}/settings/delete",
          headers: authenticated
        expect(response).to have_http_status(:no_content)
      end.to have_enqueued_job
    end
  end
end
