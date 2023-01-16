# frozen_string_literal: true

RSpec.shared_examples "a model using LastUsageTracker" do
  it "tracks its last usage" do
    subject.save!

    expect(subject).to be_tracks_last_used

    # Touch works
    subject.touch_last_used
    last = subject.reload.last_used_at
    expect(last).not_to be_nil

    # Touch only happens once per minute
    subject.touch_last_used
    expect(subject.reload.last_used_at).to eq last
    Timecop.travel(1.minute.from_now) do
      subject.touch_last_used
      expect(subject.reload.last_used_at).not_to eq last
    end
  end
end
