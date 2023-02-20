# frozen_string_literal: true

json.repository { json.partial! "v1/repositories/repository", repo: repo }
json.secrets_count secrets_count
json.permissions permissions
