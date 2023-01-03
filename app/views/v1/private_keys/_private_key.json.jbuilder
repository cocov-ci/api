# frozen_string_literal: true

json.call(private_key, :id, :name, :scope, :digest)
json.created_at private_key.created_at.iso8601
