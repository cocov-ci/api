# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::RepositorySettings" do
  let(:repo) { create(:repository) }

  before do
    @user = create(:user)
    grant(@user, access_to: repo, as: :admin)
  end

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
      allow(fake_repo).to receive_messages(name: "foobar", description: repo.description, id: 10)

      expect do
        post "/v1/repositories/#{repo.name}/settings/sync-github",
          headers: authenticated
      end.to enqueue_job

      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({ "new_name" => "foobar" })
      expect(repo.reload.name).to eq "foobar"
    end

    it "updates the repository description" do
      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      fake_repo = double(:fake_repo)
      allow(gh_app).to receive(:repo).with(repo.github_id).and_return(fake_repo)
      allow(fake_repo).to receive_messages(name: repo.name, description: "foobar", id: 10)

      expect do
        post "/v1/repositories/#{repo.name}/settings/sync-github",
          headers: authenticated
      end.to enqueue_job

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

  describe "#index" do
    {
      user: [],
      maintainer: %i[can_regen_token can_sync_github],
      admin: %i[can_regen_token can_sync_github can_delete]
    }.each do |level, opts|
      it "returns valid options for #{level} level" do
        @user = create(:user)
        grant(@user, access_to: repo, as: level)

        get "/v1/repositories/#{repo.name}/settings",
          headers: authenticated
        expect(response).to have_http_status :ok
        received_opts = response.json[:permissions]
          .to_a
          .filter(&:last)
          .map(&:first)
        expect(received_opts).to eq opts.map(&:to_s)
        expect(response.json[:repository][:id]).to eq repo.id
        expect(response.json[:secrets_count]).to eq 0
      end
    end
  end
end
