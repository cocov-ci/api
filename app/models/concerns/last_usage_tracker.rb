# frozen_string_literal: true

module LastUsageTracker
  extend ActiveSupport::Concern

  def tracks_last_used?
    true
  end

  def touch_last_used
    # Update only once per minute
    return if last_used_at && Time.current - last_used_at <= 60

    update_column(:last_used_at, Time.current)
  end
end
