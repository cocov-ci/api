# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions" do
  describe "begin_authentication" do
    it "rejects when redirect url is missing" do
      post "/auth/begin"

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :no_redirect
    end

    it "rejects invalid redirect urls" do
      post "/auth/begin", params: { redirect: "!@$%" }

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :bad_redirect_uri
    end

    it "returns a redirect uri" do
      stub_configuration!
      mock_redis!

      expect(SecureRandom).to receive(:hex).with(21).and_return("random-value-1").ordered
      expect(SecureRandom).to receive(:hex).with(21).and_return("random-value-2").ordered

      post "/auth/begin", params: { redirect: "#{@ui_base_url}/test/1" }

      expect(response).to have_http_status :ok
      redir = URI.parse(response.json(:redirect_to))
      expect(redir.to_s.split("?").first).to eq "https://github.com/login/oauth/authorize"

      query = Rack::Utils.parse_nested_query redir.query
      expect(query["allow_signup"]).to eq "false"
      expect(query["client_id"]).to eq @github_oauth_client_id
      expect(query["redirect_uri"]).to eq "#{@ui_base_url}/test/1?exchange_token=random-value-2"
      expect(query["scope"]).to eq "user:email,repo"
      expect(query["state"]).to eq "random-value-1"

      redis_data = @redis.get_json("auth:random-value-2")
      expect(redis_data[:state]).to eq "random-value-1"
    end
  end

  describe "finish authentication" do
    it "rejects when id is missing" do
      post "/auth/exchange"

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :no_exchange_token
    end

    it "rejects when state is missing" do
      post "/auth/exchange", params: { exchange_token: "exchange_token" }

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :no_state
    end

    it "rejects when code is missing" do
      post "/auth/exchange", params: { exchange_token: "exchange_token", state: "state" }

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :no_code
    end

    it "rejects when redirect is missing" do
      post "/auth/exchange", params: { exchange_token: "exchange_token", state: "state", code: "code" }

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :no_redirect
    end

    it "rejects when id does not exist" do
      expect(Cocov::Redis).to receive(:get_authentication_state).with("exchange_token").and_return(nil)

      post "/auth/exchange", params: { exchange_token: "exchange_token", state: "state", code: "code", redirect: "foo" }

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :invalid_exchange_token_or_state
    end

    it "rejects when state does not match" do
      expect(Cocov::Redis).to receive(:get_authentication_state).with("exchange_token").and_return("bla")

      post "/auth/exchange", params: { exchange_token: "exchange_token", state: "state", code: "code", redirect: "foo" }

      expect(response).to have_http_status :bad_request
      expect(response).to be_a_json_error :session, :invalid_exchange_token_or_state
    end

    it "rejects when user does not belong to organization" do
      expect(Cocov::Redis).to receive(:get_authentication_state).with("exchange_token").and_return("state")
      expect(Cocov::GitHub).to receive(:exchange_access_code).with("code", "redirect").and_return({
        access_token: "gh-token",
        scope: "user:email"
      })

      usr = double(:user)
      usr_usr = double(:user_user)
      allow(usr).to receive(:user).and_return(usr_usr)
      allow(usr_usr).to receive(:login).and_return("dummy")

      expect(Cocov::GitHub).to receive(:user_membership).with("dummy").and_return(:not_a_member)
      expect(Cocov::GitHub).to receive(:for_user).with("gh-token").and_return(usr)

      post "/auth/exchange",
        params: { exchange_token: "exchange_token", state: "state", code: "code", redirect: "redirect" }

      expect(response).to have_http_status :forbidden
      expect(response).to be_a_json_error :session, :not_an_org_member
    end

    it "rejects outside collaborators when configured to do so" do
      expect(Cocov::Redis).to receive(:get_authentication_state).with("exchange_token").and_return("state")
      expect(Cocov::GitHub).to receive(:exchange_access_code).with("code", "redirect").and_return({
        access_token: "gh-token",
        scope: "user:email"
      })

      stub_const("Cocov::ALLOW_OUTSIDE_COLLABORATORS", false)

      usr = double(:user)
      usr_usr = double(:user_user)
      allow(usr).to receive(:user).and_return(usr_usr)
      allow(usr_usr).to receive(:login).and_return("dummy")

      expect(Cocov::GitHub).to receive(:user_membership).with("dummy").and_return(:outside_collaborator)
      expect(Cocov::GitHub).to receive(:for_user).with("gh-token").and_return(usr)

      post "/auth/exchange",
        params: { exchange_token: "exchange_token", state: "state", code: "code", redirect: "redirect" }

      expect(response).to have_http_status :forbidden
      expect(response).to be_a_json_error :session, :outside_collaborator_not_allowed
    end

    it "returns a token and the user name" do
      expect(Cocov::Redis).to receive(:get_authentication_state).with("exchange_token").and_return("state")
      expect(Cocov::GitHub).to receive(:exchange_access_code).with("code", "redirect").and_return({
        access_token: "gh-token",
        scope: "user:email"
      })

      emails = {}
      email = lambda do |verified|
        em = Faker::Internet.email
        dbl = double("email-resource")
        allow(dbl).to receive_messages(email: em, verified?: verified)
        emails[em] = verified
        dbl
      end

      usr = double(:user)
      usr_usr = double(:user_user)
      allow(usr).to receive_messages(user: usr_usr, emails: [
                                       email[true], email[false], email[true]
                                     ])
      allow(usr_usr).to receive_messages(login: "dummy", avatar_url: nil, id: 27)

      emails = {}

      expect(Cocov::GitHub).to receive(:user_membership).with("dummy").and_return(:member)
      allow(Cocov::GitHub).to receive(:for_user).with("gh-token").and_return(usr)

      expect(SecureRandom).to receive(:hex).with(32).and_return("lol_random_token")

      post "/auth/exchange",
        params: { exchange_token: "exchange_token", state: "state", code: "code", redirect: "redirect" }

      expect(response).to have_http_status :ok
      expect(response.json).to eq({
        "token" => "coa_lol_random_token",
        "name" => "dummy",
        "admin" => false
      })

      usr = User.first
      expect(usr.github_token).to eq "gh-token"
      expect(usr.emails.count).to eq 2
      emails.each do |k, v|
        expect(usr.emails.exists?(email: k)).to be v
      end
      expect(usr.tokens.count).to eq 1
      expect(usr.tokens.first).to be_auth
    end
  end

  describe "reauthentication" do
    it "allow users to reauthenticate" do
      expect(Cocov::Redis).to receive(:get_authentication_state).twice.with("exchange_token").and_return("state")
      expect(Cocov::GitHub).to receive(:exchange_access_code).twice.with("code", "redirect").and_return({
        access_token: "gh-token",
        scope: "user:email"
      })

      emails = {}
      email = lambda do |verified|
        em = Faker::Internet.email
        dbl = double("email-resource")
        allow(dbl).to receive_messages(email: em, verified?: verified)
        emails[em] = verified
        dbl
      end

      usr = double(:user)
      usr_usr = double(:user_user)
      allow(usr).to receive_messages(user: usr_usr, emails: [
                                       email[true], email[false], email[true]
                                     ])
      allow(usr_usr).to receive_messages(login: "dummy", avatar_url: nil, id: 27)

      expect(Cocov::GitHub).to receive(:user_membership).twice.with("dummy").and_return(:member)
      allow(Cocov::GitHub).to receive(:for_user).with("gh-token").and_return(usr)

      expect(SecureRandom).to receive(:hex).once.ordered.with(32).and_return("lol_random_token")
      expect(SecureRandom).to receive(:hex).once.ordered.with(32).and_return("lol_random_token_2")

      post "/auth/exchange",
        params: { exchange_token: "exchange_token", state: "state", code: "code", redirect: "redirect" }

      expect(response).to have_http_status :ok
      expect(response.json).to eq({
        "token" => "coa_lol_random_token",
        "name" => "dummy",
        "admin" => false
      })

      post "/auth/exchange",
        params: { exchange_token: "exchange_token", state: "state", code: "code", redirect: "redirect" }

      expect(response).to have_http_status :ok
      expect(response.json).to eq({
        "token" => "coa_lol_random_token_2",
        "name" => "dummy",
        "admin" => false
      })
    end
  end
end
