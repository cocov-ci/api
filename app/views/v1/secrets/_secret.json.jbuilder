# frozen_string_literal: true

json.call(secret, :id, :name, :scope)
json.created_at secret.created_at.iso8601
