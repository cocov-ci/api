# frozen_string_literal: true

json.artifacts items, partial: "v1/tool_cache/artifact", as: :artifact
json.paging paging_info(items)
