# frozen_string_literal: true

store = ActiveSupport::Cache.lookup_store(:redis_cache_store, expires_in: 1.day, url: Cocov::REDIS_CACHE_URL)
stack = Faraday::RackBuilder.new do |builder|
  builder.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false, store:)
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack
