# frozen_string_literal: true

RSpec.shared_examples "a history model" do |history_field|
  it "returns history for a repository" do
    start_date = "2022-12-20T00:00:00Z"
    end_date = "2022-12-27T00:00:00Z"
    data = [
      ["2022-12-18T00:00:00Z", 100], # Out of range
      ["2022-12-19T00:00:00Z", 5],   # Out of range, should be chosen as the
      # value for 2022-12-20
      ["2022-12-21T00:00:00Z", 10], # \
      ["2022-12-21T00:00:00Z", 20], # |- Same day, should take the largest
      ["2022-12-21T00:00:00Z", 30], # /
      ["2022-12-22T00:00:00Z", 40],
      ["2022-12-23T00:00:00Z", 50],
      ["2022-12-24T00:00:00Z", 60],
      # Day 25 does not exist, should be 60
      ["2022-12-26T00:00:00Z", 70],
      ["2022-12-27T00:00:00Z", 80],
      ["2022-12-28T00:00:00Z", 5]
    ]

    repo = create(:repository)
    branch = create(:branch, repository: repo)

    data.each do |args|
      created_at, qty = args
      described_class.create!(repository: repo, branch_id: branch.id, history_field => qty, created_at:)
    end

    expected = {
      20 => 5,
      21 => 30,
      22 => 40,
      23 => 50,
      24 => 60,
      25 => 60,
      26 => 70,
      27 => 80
    }

    data = described_class.history_for(repo, branch.id, start_date, end_date)
    expected.keys.each.with_index do |k, idx|
      h = data[idx]
      expect(h[:date].day).to eq k
      expect(h[:value]).to eq expected[k]
    end
  end

  it "updates branch data when registering entries" do
    repo = create(:repository)
    branch = create(:branch, repository: repo)
    commit = create(:commit, repository: repo)
    branch.head = commit
    branch.save!

    Timecop.freeze do
      described_class.register_history!(commit, 10)
      data = described_class.history_for(repo, branch.id, Time.zone.now, Time.zone.now)
      expect(data.length).to eq 1
      expect(data.first[:value]).to eq 10
    end
  end

  it "indicates when no data is available" do
    repo = create(:repository)
    branch = create(:branch, repository: repo)
    Timecop.freeze do
      data = described_class.history_for(repo, branch.id, Time.zone.now, Time.zone.now)
      expect(data).to be_a(Array)
      expect(data.all? { _1[:date].is_a? Date }).to be true
      expect(data.all? { _1[:value].nil? }).to be true
    end
  end

  it "returns initial data" do
    repo = create(:repository)
    branch = create(:branch, repository: repo)
    commit = create(:commit, repository: repo)
    branch.head = commit
    branch.save!

    Timecop.freeze do
      described_class.register_history!(commit, 10)
      data = described_class.history_for(repo, branch.id, 31.days.ago, Time.zone.now)
      expect(data.all? { _1[:date].is_a? Date }).to be true
      expect(data.pop[:value]).to eq 10
      expect(data.all? { _1[:value].nil? }).to be true
    end
  end

  it "returns the last registered data" do
    repo = create(:repository)
    branch = create(:branch, repository: repo)
    commit = create(:commit, repository: repo)
    branch.head = commit
    branch.save!

    Timecop.freeze do
      described_class.register_history!(commit, 10)
      described_class.register_history!(commit, 30)
      described_class.register_history!(commit, 20)
      data = described_class.history_for(repo, branch.id, 31.days.ago, Time.zone.now)
      expect(data.all? { _1[:date].is_a? Date }).to be true
      expect(data.pop[:value]).to eq 20
      expect(data.all? { _1[:value].nil? }).to be true
    end
  end
end
