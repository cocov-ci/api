# frozen_string_literal: true

json.partial! "v1/admin/service_token", token: token
json.token_value token.value
