# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::Status::SidekiqProbes do
  subject(:server) do
    described_class.new(address: "127.0.0.1", port: 8668)
  end

  let(:url) { "http://127.0.0.1:8668" }

  around do |spec|
    WebMock.allow_net_connect!
    server.start
    spec.run
    server.stop
    WebMock.disable_net_connect!
  end

  it "returns OK when requesting readiness" do
    response = HTTParty.get("#{url}/system/probes/readiness")
    expect(response).to be_success
    expect(JSON.parse(response.body)).to eq({ "ok" => true })
  end

  it "returns OK when requesting liveness" do
    response = HTTParty.get("#{url}/system/probes/liveness")
    expect(response).to be_success
    expect(JSON.parse(response.body)).to eq({ "ok" => true })
  end
end
