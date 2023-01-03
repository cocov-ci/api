# frozen_string_literal: true

module Cocov
  class GitHub
    class TokenAcquisitionError < StandardError; end
    GITHUB_INSTALLATION_TOKEN_KEY = "github:installation:token"

    # Public: Returns a Octokit client for the configured GitHub App
    # installation.
    #
    # May raise TokenAcquisitionError in case GitHub API returns an error, or
    # Cocov::Redis::LockFailedError in case an exclusive lock for the resource
    # cannot be acquired.
    def self.app
      app = for_user(installation_token.token)
      return yield app if block_given?

      app
    end

    # Internal: Attempts to obtain a valid installation token from Redis,
    # automatically creating one if it does not exist or has expired.
    #
    # Returns an InstallationToken instance on success, raises
    # Redis::LockFailedError or TokenAcquisitionError otherwise.
    def self.installation_token
      retried = 0
      begin
        Redis.lock(GITHUB_INSTALLATION_TOKEN_KEY, 5000) do
          current_token = Redis.get_json(GITHUB_INSTALLATION_TOKEN_KEY)
          return make_installation_token if current_token.nil?

          token = InstallationToken.new(current_token)
          return make_installation_token if token.expired?

          token
        end
      rescue Redis::LockFailedError => e
        raise e if retried > 3

        retried += 1
        retry
      end
    end

    # Internal: Creates a new GitHub installation token.
    #
    # Returns a new InstallationToken instance on success, raises
    # TokenAcquisitionError otherwise.
    def self.make_installation_token
      resp = HTTParty.post("https://api.github.com/app/installations/#{GITHUB_APP_INSTALLATION_ID}/access_tokens",
        headers: {
          "Authorization" => "Bearer #{jwt_token}",
          "Accept" => "application/vnd.github+json"
        })
      raise TokenAcquisitionError, "HTTP #{resp.code}: #{resp.body}" unless resp.success?

      data = JSON.parse(resp.body, symbolize_names: true)
      InstallationToken.new(data).tap do |token|
        Redis.instance.set(GITHUB_INSTALLATION_TOKEN_KEY, token.to_json)
      end
    end

    # Public: Returns a new Octokit client authenticated as the Cocov OAuth
    # application.
    def self.oauth_app
      Octokit::Client.new(
        client_id: GITHUB_OAUTH_CLIENT_ID,
        client_secret: GITHUB_OAUTH_CLIENT_SECRET
      )
    end

    # Public: Returns a new Octokit client configured to use the provided token
    def self.for_user(token)
      Octokit::Client.new(access_token: token)
    end

    # Internal: Creates a new JWT token for communicating with GitHub.
    def self.jwt_token
      # :nocov:
      @private_key ||= OpenSSL::PKey::RSA.new(GITHUB_APP_PRIVATE_KEY)
      payload = {
        # issued at time, 60 seconds in the past to allow for clock drift
        iat: Time.now.to_i - 60,
        exp: Time.now.to_i + (10 * 60), # 10 minutes
        iss: GITHUB_APP_ID
      }

      JWT.encode(payload, @private_key, "RS256")
      # :nocov:
    end

    # Public: exchanges a given code and redirect uri with an bearer token
    #
    # Returns a Hash containing token information, or raises
    # TokenAcquisitionError.
    def self.exchange_access_code(code, redirect)
      resp = HTTParty.post("https://github.com/login/oauth/access_token",
        headers: {
          "Accept" => "application/vnd.github+json"
        },
        body: {
          client_id: GITHUB_OAUTH_CLIENT_ID,
          client_secret: GITHUB_OAUTH_CLIENT_SECRET,
          code:,
          redirect_uri: redirect
        })
      raise TokenAcquisitionError, "HTTP #{resp.code}: #{resp.body}" unless resp.success?

      JSON.parse(resp.body, symbolize_names: true).tap do |data|
        raise TokenAcquisitionError, "HTTP #{resp.code}: #{resp.body}" if data.key? :error
      end
    end

    # Public: Returns the membership of a given user against the current
    # configured organization.
    #
    # Returns :member, :outside_collaborator, or :not_a_member
    def self.user_membership(name)
      app do |client|
        client.auto_paginate = true
        return :member if app.org_member? GITHUB_ORGANIZATION_NAME, name
        return :outside_collaborator if app.outside_collaborators(GITHUB_ORGANIZATION_NAME, per_page: 100).any? do |col|
          col.login == name
        end

        :not_a_member
      end
    end
  end
end
