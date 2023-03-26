# frozen_string_literal: true

json.call(artifact, :id, :name, :name_hash, :size, :engine, :mime)
json.created_at artifact.created_at.iso8601
json.last_used_at artifact.last_used_at.iso8601
