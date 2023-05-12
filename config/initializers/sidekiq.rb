# frozen_string_literal: true

Sidekiq.configure_client do |config|
  config.redis = { url: Cocov::SIDEKIQ_REDIS_URL }
end

Sidekiq.configure_server do |config|
  config.redis = { url: Cocov::SIDEKIQ_REDIS_URL }

  config.on :startup do
    if !ENV["SIDEKIQ_WORKER_ID"] || ENV["SIDEKIQ_WORKER_ID"] == "0"
      Cocov::Status::SidekiqProbes.new(
        address: Cocov::SIDEKIQ_PROBE_ADDRESS,
        port: Cocov::SIDEKIQ_PROBE_PORT
      ).start
    end
  end
end
