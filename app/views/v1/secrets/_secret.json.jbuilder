# frozen_string_literal: true

json.call(secret, :id, :name, :scope)
json.owner do
  json.call(secret.owner, :login, :avatar_url)
end

json.last_used_at secret.last_used_at&.iso8601
json.created_at secret.created_at.iso8601
