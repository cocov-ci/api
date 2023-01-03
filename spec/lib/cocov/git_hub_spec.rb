# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::GitHub do
  subject(:github) { described_class }

  let(:token_redis_key) { Cocov::GitHub::GITHUB_INSTALLATION_TOKEN_KEY }

  describe "#app" do
    before do
      install_token = double(:installation_token)
      expect(install_token).to receive(:token).and_return("install-token")
      expect(described_class).to receive(:installation_token).and_return(install_token)
    end

    it "returns a client for the current installation" do
      client = github.app
      expect(client.access_token).to eq "install-token"
    end

    it "yields the client to a given block" do
      result = github.app do |client|
        expect(client.access_token).to eq "install-token"
        :result
      end

      expect(result).to eq :result
    end
  end

  describe "#installation_token" do
    before do
      mock_redis!
    end

    it "automatically returns a non-expired token" do
      bypass_redlock!
      token_string = SecureRandom.hex(10)
      expect(github).not_to receive(:make_installation_token)

      @redis.set(token_redis_key, {
        token: token_string,
        expires_at: 1.day.from_now.utc.iso8601
      }.to_json)

      token = github.installation_token
      expect(token).to be_a Cocov::GitHub::InstallationToken
      expect(token.token).to eq token_string
    end

    it "automatically retries obtaining a lock and returns a success" do
      # First and second redlock call fails
      2.times do
        expect(Cocov::Redis).to receive(:lock)
          .with(anything, anything)
          .and_raise(Cocov::Redis::LockFailedError)
          .ordered
      end

      # Third call succeeds
      expect(Cocov::Redis).to receive(:lock)
        .with(anything, anything)
        .and_return(:foo)
        .ordered

      expect(github.installation_token).to eq(:foo)
    end

    it "re-raises the lock error in case no lock attempt succeeds" do
      # Four first calls fails
      4.times do
        expect(Cocov::Redis).to receive(:lock)
          .with(anything, anything)
          .and_raise(Cocov::Redis::LockFailedError)
          .ordered
      end

      # Fifth call fails too
      last_error = Cocov::Redis::LockFailedError.new
      expect(Cocov::Redis).to receive(:lock)
        .with(anything, anything)
        .and_raise(last_error)
        .ordered

      expect { github.installation_token }.to raise_error(last_error)
    end

    it "creates a new token in case no token is available" do
      bypass_redlock!
      expect(Cocov::Redis).to receive(:get_json).with(token_redis_key).and_return(nil)
      expect(github).to receive(:make_installation_token).and_return(:new_token)

      expect(github.installation_token).to eq :new_token
    end

    it "creates a new token in case the current token is expired" do
      bypass_redlock!
      @redis.set(token_redis_key, {
        token: "expired_token",
        expires_at: 1.day.ago.utc.iso8601
      }.to_json)
      expect(github).to receive(:make_installation_token).and_return(:new_token)
      expect(github.installation_token).to eq :new_token
    end
  end

  describe "#make_installation_token" do
    it "creates a new installation token and stores it on Redis" do
      mock_redis!
      stub_configuration!
      access_token = SecureRandom.hex(12)
      expires_at = 1.hour.from_now.utc.iso8601

      stub_request(:post, "https://api.github.com/app/installations/#{@github_app_installation_id}/access_tokens")
        .with(
          headers: {
            "Accept" => "application/vnd.github+json",
            "Authorization" => "Bearer DUMMY-JWT-TOKEN"
          }
        )
        .to_return(
          status: 200,
          body: {
            expires_at:,
            token: access_token
          }.to_json,
          headers: {}
        )

      expect(github).to receive(:jwt_token).and_return("DUMMY-JWT-TOKEN")
      token = github.make_installation_token
      expect(token.expires_at).to be_future
      expect(token.token).to eq access_token
    end
  end

  describe "#user_memebership" do
    let(:client) { double(:client) }

    before do
      stub_configuration!
      allow(client).to receive(:auto_paginate=).with(anything)
      allow(github).to receive(:app).and_invoke(lambda do |&block|
        return block.call(client) unless block.nil?

        client
      end)
    end

    it "indicates when a user is not a member of the current organization" do
      expect(client).to receive(:org_member?)
        .with(@github_organization_name, "dummy")
        .and_return(false)
      expect(client).to receive(:outside_collaborators)
        .with(@github_organization_name, anything)
        .and_return([])

      expect(github.user_membership("dummy")).to eq :not_a_member
    end

    it "indicates when a user is an organization member" do
      expect(client).to receive(:org_member?)
        .with(@github_organization_name, "dummy")
        .and_return(true)
      expect(client).not_to receive(:outside_collaborators)

      expect(github.user_membership("dummy")).to eq :member
    end

    it "indicates when a user is an outside collaborator" do
      expect(client).to receive(:org_member?)
        .with(@github_organization_name, "dummy")
        .and_return(false)
      outsider = double(:outsider)
      expect(outsider).to receive(:login).and_return "dummy"

      expect(client).to receive(:outside_collaborators)
        .with(@github_organization_name, anything)
        .and_return([outsider])

      expect(github.user_membership("dummy")).to eq :outside_collaborator
    end
  end

  describe "#exchange_access_code" do
    before { stub_configuration! }

    def fake_access_token_request(body, status: 200)
      stub_request(:post, "https://github.com/login/oauth/access_token")
        .with(
          body: {
            client_id: @github_oauth_client_id,
            client_secret: @github_oauth_client_secret,
            code: "code",
            redirect_uri: "redirect"
          }.to_param,
          headers: {
            "Accept" => "application/vnd.github+json",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "User-Agent" => "Ruby"
          }
        )
        .to_return(status:, body: body.to_json, headers: {})
    end

    it "returns the parsed response in case it is successful" do
      fake_access_token_request({ ok: true })
      data = described_class.exchange_access_code("code", "redirect")
      expect(data[:ok]).to be true
    end

    it "raises an error if request returns an non-successful http status" do
      fake_access_token_request({ oh_no: true }, status: 400)
      expect { described_class.exchange_access_code("code", "redirect") }
        .to raise_error(Cocov::GitHub::TokenAcquisitionError)
    end

    it "raises an error if response contains an error key" do
      fake_access_token_request({ error: true }, status: 200)
      expect { described_class.exchange_access_code("code", "redirect") }
        .to raise_error(Cocov::GitHub::TokenAcquisitionError)
    end
  end
end
