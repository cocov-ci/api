# frozen_string_literal: true

module Cocov
  module SpecHelpers
    def stub_configuration!
      @github_organization_name = Faker::BossaNova.artist.parameterize
      @github_app_id = "gh-app-id-#{SecureRandom.hex(10)}"
      @github_app_installation_id = (SecureRandom.random_number * 1e10).round.to_s
      @github_oauth_client_id = "gh-oauth-id-#{SecureRandom.hex(10)}"
      @github_oauth_client_secret = "gh-oauth-secret-#{SecureRandom.hex(10)}"
      @ui_base_url = "https://cocov.#{@github_organization_name}.example.com"
      @api_base_url = "https://cocov-api.#{@github_organization_name}.example.com"

      {
        GITHUB_ORGANIZATION_NAME: @github_organization_name,
        GITHUB_APP_ID: @github_app_id,
        GITHUB_APP_INSTALLATION_ID: @github_app_installation_id,
        GITHUB_OAUTH_CLIENT_ID: @github_oauth_client_id,
        GITHUB_OAUTH_CLIENT_SECRET: @github_oauth_client_secret,
        UI_BASE_URL: @ui_base_url,
        API_BASE_URL: @api_base_url
      }.each do |k, v|
        stub_const("Cocov::#{k}", v)
      end
    end

    def mock_redis!
      @redis = MockRedis.new
      @cache = MockRedis.new
      allow(Cocov::Redis).to receive(:instance).and_return(@redis)
      allow(Cocov::Redis).to receive(:cache).and_return(@cache)
    end

    def bypass_redlock!
      allow(Cocov::Redis).to receive(:lock).with(anything, anything).and_yield
    end

    def stub_crypto_key!
      stub_const("Cocov::CRYPTOGRAPHIC_KEY", "6a3094175b97cc4eff61630452425b1d")
    end

    def self.http_mime(named)
      Mime::LOOKUP.find { |_k, v| v.symbol == named }.first
    end

    JSON_FORMAT = http_mime(:json)

    def authenticate(user, **other_headers)
      as = other_headers.delete(:as) || :auth

      token = if as == :service
        ServiceToken.create(owner: user, description: "A Service Token")
      else
         user.tokens.create(kind: as)
       end

      other_headers["HTTP_ACCEPT"] = SpecHelpers.http_mime(other_headers.delete(:format)) if other_headers.key? :format

      {
        "HTTP_AUTHORIZATION" => "bearer #{token.value}",
        "HTTP_ACCEPT" => JSON_FORMAT
      }.merge(**other_headers)
    end

    def authenticated(**other_headers)
      @user = create(:user)
      authenticate(@user, **other_headers)
    end

    def fixture_file_path(*named)
      Rails.root.join('spec', 'fixtures', *named)
    end

    def fixture_file(*named)
      File.read(fixture_file_path(*named))
    end

    def stub_s3!
      @s3 = Aws::S3::Resource.new(stub_responses: true).tap do |s3|
        allow(Aws::S3::Resource).to receive(:new).and_return(s3)
      end
    end

    def github_delivery_header(event)
      { "HTTP_X_GITHUB_EVENT" => event, "HTTP_X_GITHUB_DELIVERY" => SecureRandom.uuid }
    end
  end
end

module ActionDispatch
  class TestResponse
    def json(*path)
      unless @_parsed_response
        data = JSON.parse(body, symbolize_names: true)
        data = data.with_indifferent_access if data.is_a? Hash
        @_parsed_response = data
      end

      return @_parsed_response if path.empty?

      @_parsed_response.dig(*path)
    end
  end
end

class MockRedis
  def get_json(*args, **kwargs)
    data = get(*args, **kwargs)
    return nil if data.nil?

    data = JSON.parse(data, symbolize_names: true)
    data = data.with_indifferent_access if data.is_a? Hash
    data
  end

  # remove once https://github.com/sds/mock_redis/pull/250 is merged
  def getdel(key)
    get(key).tap { del(key) }
  end

  def getex(key, ex: nil, px: nil, exat: nil, pxat: nil, persist: nil)
    val = get(key)
    return val if val.nil?

    expire(key, ex) if ex
    pexpire(key, px) if px
    expireat(key, exat) if exat
    pexpireat(key, pxat) if pxat

    val
  end
end
