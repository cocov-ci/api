# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.2"

gem "rails", "~> 7.0.5"

gem "pg", "~> 1.1"

gem "puma", "~> 5.0"

gem "jbuilder"

gem "jwt"

gem "faraday-retry"

gem "octokit"

gem "redis"

gem "httparty"

gem "redlock"

gem "faraday-http-cache"

gem "kaminari"

gem "ssh_data", "~> 1.3"

gem "bootsnap", require: false

gem "aws-sdk-s3", "~> 1.117"

gem "sidekiq", "~> 7.1"

gem "github-linguist", "~> 7.24"

gem "rouge", "~> 4.0"

gem "webrick", "~> 1.8.1", require: false

gem "silencer", require: false

group :development, :test do
  gem "factory_bot_rails"
  gem "faker"
  gem "mock_redis"
  gem "rspec-rails", "~> 5.0.0"
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", "~> 2.17"
  gem "rubocop-rspec", "~> 2.16"
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
  gem "timecop", "~> 0.9.6"
  gem "webmock"
end

group :development do
  gem "annotate"
  gem "byebug"
  gem "guard", require: false
  gem "guard-rspec", require: false
  gem "listen"
  gem "pry-rails"
end
