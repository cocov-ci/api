# frozen_string_literal: true

json.call(token, :id, :description)
json.created_by token.owner.login
json.created_at token.created_at.iso8601
json.last_used_at token.last_used_at&.iso8601
