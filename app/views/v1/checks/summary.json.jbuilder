# frozen_string_literal: true

json.array! checks do |check|
  json.name check.plugin_name
  json.call(check, :started_at, :status)

  if check.completed? || check.errored?
    json.call(check, :finished_at)
    json.duration (check.finished_at - check.started_at).to_i
  end

  json.issue_count issues_count.fetch(check.plugin_name, 0) if check.completed?
end
