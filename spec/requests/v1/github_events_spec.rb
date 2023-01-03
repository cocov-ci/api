# frozen_string_literal: true

require "rails_helper"

RSpec.describe "V1::GithubEvents" do
  let(:payload) { fixture_file("github_push_event.json") }

  it "handles incoming push events" do
    mock_redis!

    create(:repository, name: "api")
    post "/v1/github/events",
      params: payload,
      headers: { "HTTP_X_GITHUB_EVENT" => "push", "HTTP_X_GITHUB_DELIVERY" => SecureRandom.uuid }

    expect(response).to have_http_status(:ok)
  end

  it "processes deferred coverages when commit is created on push" do
    mock_redis!

    sha = "6858adf07e5cd43f9c5d87573369fa354d20a076"
    repo = create(:repository, name: "api")
    @redis.set("commit:coverage:#{repo.id}:#{repo.id}:#{sha}", { bla: true }.to_json)

    data = JSON.parse(payload)
    data["head_commit"]["id"] = sha

    expect do
      post "/v1/github/events",
        params: data.to_json,
        headers: { "HTTP_X_GITHUB_EVENT" => "push", "HTTP_X_GITHUB_DELIVERY" => SecureRandom.uuid }

      expect(response).to have_http_status(:ok)
    end.to have_enqueued_job
  end
end
