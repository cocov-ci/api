# frozen_string_literal: true

require "rails_helper"

RSpec.describe RequestCacheEvictionJob do
  subject(:job) { described_class.new }

  before { mock_redis! }

  it "requests evictions" do
    repo = create(:repository)
    dates = [
      1.hour.ago,
      1.day.ago,
      1.week.ago
    ]
    items = dates.map { create(:cache_artifact, repository: repo, size: 1024, last_used_at: _1) }

    # Here we have 3072 bytes. Let's pretend our max is 2000.
    # Items 1 and 2 should be evicted.
    stub_const("Cocov::REPOSITORY_CACHE_MAX_SIZE", 2000)
    job.perform(repo.id)

    expect(@redis.llen("cocov:cached:housekeeping_tasks")).to eq 1
    task = JSON.parse(@redis.lindex("cocov:cached:housekeeping_tasks", 0), symbolize_names: true)

    expect(task[:task]).to eq "evict-artifact"
    expect(task[:repository]).to eq repo.id
    expect(task[:objects]).to eq [items[2].id, items[1].id]
  end
end
