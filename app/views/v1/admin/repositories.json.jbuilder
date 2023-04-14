# frozen_string_literal: true

json.repositories repositories do |r|
  json.call(r, :id, :name, :cache_size, :commits_size)
  json.created_at r.created_at.iso8601
  json.accessible_by_count counts[r.id]
end

json.paging paging_info(repositories)
