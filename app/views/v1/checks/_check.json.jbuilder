# frozen_string_literal: true

json.call(check, :id, :plugin_name, :status)

json.started_at check.started_at.iso8601 unless check.waiting?
json.finished_at check.finished_at.iso8601 if check.succeeded? || check.errored?
