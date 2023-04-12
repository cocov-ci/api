# frozen_string_literal: true

json.enabled enabled

if enabled
  json.artifacts artifacts, partial: "v1/admin/tool_cache_artifact", as: :tool
  json.paging paging_info(artifacts)
end
