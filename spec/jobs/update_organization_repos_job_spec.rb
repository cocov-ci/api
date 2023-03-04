# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateOrganizationReposJob do
  subject(:job) { described_class.new }

  before { stub_configuration! }

  it "obtains and stores all repositories from GitHub" do
    names = ["xyzzy", "plugh", "plover", "fee fie foe foo"]
    repos = names.map.with_index do |name, idx|
      {
        id: idx + 1,
        name:,
        description: nil,
        created_at: Time.zone.now,
        pushed_at: Time.zone.now
      }
    end

    fake_app = double(:app)
    allow(Cocov::GitHub).to receive(:app).and_return(fake_app)
    allow(fake_app).to receive(:org_repos)
      .with(@github_organization_name)
      .and_return(repos)
    allow(fake_app).to receive(:last_response)
      .and_return(double(:last_response, headers: { etag: "foobar" }))

    expect(Cocov::Redis).to receive(:set_organization_repositories)
      .with(items: anything, etag: "foobar") do |items:, etag:|
        expect(etag).to eq "foobar"
        expect(items.pluck(:name)).to eq names.reverse
      end

    job.perform
  end
end
