# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::SidekiqRouteConstraint do
  subject(:constraint) { described_class }

  before do
    mock_redis!
    stub_crypto_key!
  end

  let(:user) { create(:user, :admin) }

  it "generates a exchange token" do
    exchange = constraint.generate_exchange_token(user)
    expect(exchange).to be_start_with("csp_")
    expect(@redis.exists?("cocov:sidekiq_auth:#{OpenSSL::Digest::SHA256.hexdigest(exchange)}")).to be true
  end

  it "exchanges a generated token" do
    exchange = constraint.generate_exchange_token(user)
    session = constraint.session_for_exchange_token(exchange)

    expect(@redis.exists?("cocov:sidekiq_auth:#{OpenSSL::Digest::SHA256.hexdigest(exchange)}")).to be false
    expect(@redis.exists?("cocov:sidekiq_session:#{OpenSSL::Digest::SHA256.hexdigest(session)}")).to be true
  end

  it "recalls generated sessions" do
    exchange = constraint.generate_exchange_token(user)
    session = constraint.session_for_exchange_token(exchange)
    user_from_session = constraint.user_for_session(session)
    expect(user_from_session.id).to eq user.id
  end

  describe "#matches?" do
    let(:session) do
      exchange = constraint.generate_exchange_token(user)
      constraint.session_for_exchange_token(exchange)
    end

    let(:request) do
      double(:request, session: { cocov_sidekiq_session_id: session })
    end

    it "matches a valid session" do
      expect(constraint.new.matches?(request)).to be true
    end

    it "does not match a non-admin user" do
      user.admin = false
      user.save!
      expect(constraint.new.matches?(request)).to be false
    end

    it "does not match a user with corrupt session" do
      @redis.set("cocov:sidekiq_session:#{OpenSSL::Digest::SHA256.hexdigest(session)}", "LOL")
      expect(constraint.new.matches?(request)).to be false
    end
  end
end
