# frozen_string_literal: true

json.call(tool, :id, :name, :name_hash, :size, :engine, :mime)
json.created_at tool.created_at.iso8601
json.last_used_at tool.last_used_at.iso8601
