# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::Redis do
  subject(:client) { described_class }

  before { mock_redis! }

  it "makes authentication keys" do
    expect(SecureRandom).to receive(:hex).with(21).and_return("random-value-1").ordered
    expect(SecureRandom).to receive(:hex).with(21).and_return("random-value-2").ordered

    auth = client.make_authentication_keys
    expect(auth[:id]).to eq "random-value-2"
    expect(auth[:state]).to eq "random-value-1"
    expect(@redis.get("auth:random-value-2")).to eq({ state: "random-value-1" }.to_json)
  end

  it "gets authentication state" do
    expect(SecureRandom).to receive(:hex).with(21).and_return("random-value-1").ordered
    expect(SecureRandom).to receive(:hex).with(21).and_return("random-value-2").ordered
    client.make_authentication_keys

    expect(@redis.exists("auth:random-value-2")).to eq 1
    state = client.get_authentication_state("random-value-2")
    expect(state).to eq "random-value-1"
    expect(@redis.exists("auth:random-value-2")).to eq 0
  end

  it "handles locks" do
    # This uses a real redis instance

    called = false
    client.lock("foo:bar", 10) do
      called = true
    end
    expect(called).to be true
  end
end
