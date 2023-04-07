# frozen_string_literal: true

json.repository { json.partial! "v1/repositories/repository", repo: repo }
json.enabled enabled

if enabled
  json.storage_used usage
  json.storage_limit max_size
  json.artifacts artifacts, partial: "v1/repository_cache_settings/artifact", as: :artifact
  json.paging paging_info(artifacts)
end
